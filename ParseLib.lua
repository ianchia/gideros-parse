--[[
ParseLib
- provides Lua hooks into the ParseSDK via BhWax
- dispatches "PFLoginComplete" event from ParseLib.eventDispatcher on successful login
- dispatches "PFLoginCancelled" event from ParseLib.eventDispatcher on login screen dismiss button click
- dispatches "PFObjectSaveComplete" event (with success, error, object fields) when an async object save is complete
- dispatches "PFQueryComplete" event (with error, objects fields) when a query has completed


## MIT License: Copyright (C) 2013. Jamie Hill, Push Poke

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

require "DefaultSettingsViewController"

-- Cache policy enums
kPFCachePolicyIgnoreCache = 0
kPFCachePolicyCacheOnly = 1
kPFCachePolicyNetworkOnly = 2
kPFCachePolicyCacheElseNetwork = 3
kPFCachePolicyNetworkElseCache = 4
kPFCachePolicyCacheThenNetwork = 5


ParseLib = Core.class()

-- init
-- [@param] String	Your Facebook AppID
-- [@param] String	Cache policy to use for queries (see setCachePolicy function)
-- [@param] Number	Max age for query cache
function ParseLib:init(facebookAppId, cachePolicy, cacheTTL)
	self.pfuser = self:currentUser()

	-- setup facebook
	if facebookAppId then
		self.facebookAppId = facebookAppId
		PFFacebookUtils:initializeWithApplicationId(self.facebookAppId)
	end
		
	-- set default cache policy (Parse default to "ignoreCache")
	if cachePolicy ~= nil then
		self:setCachePolicy(cachePolicy)
	end
	
	-- set default cache TTL
	if cacheTTL ~= nil then
		self:setCacheTTL(cacheTTL)
	end
	
	-- dispatcher for handling parse events
	myDis = Core.class(EventDispatcher)
	self.eventDispatcher = myDis.new()
end

-- test setting a TestObject to Parse to verify setup
-- @return Boolean	Whether or not it was saved to Parse
function ParseLib:test()
	-- save key value to Parse without async
	local testObj = self:createObj("TestObject")
	self:addToObj(testObj, "foo", "bar")
	return self:saveObj(testObj, false)	
end

-- create PFObject
-- @param String	The className for the object
-- @return PFObject		The object for a given className
function ParseLib:createObj(className)
	return PFObject:objectWithClassName(className)
end

-- add a key/value pair to a PFObject
-- @param PFObject	The object you're adding to
-- @param String	The key to add
-- @param Mixed		The associated value
-- @return Boolean	Whether the data was successfully added. Should always be true unless invalid params.
function ParseLib:addToObj(obj, key, value)
	if obj and key then
		local success = true
		-- ensure only valid types can be set
		if type(value) == "string" or type(value) == "number" or type(value) == "table" or type(value) == "boolean" then
			obj:setObject_forKey(value, key)
		else
			-- invalid data type
			-- e.g. can not set a function or userdata as value
			return false
		end
		return success
	else
		-- invalid params
		return false
	end
end

-- delete a PFObject
-- @param PFObject	The object to delete
function ParseLib:deleteObj(obj)
	if obj then
		obj:deleteInBackground()
	end
end

-- save PFObject
-- @param PFObject	The object to save
-- [@param] Boolean		Whether to save the object on a background thread (async). Default true. 
-- @return Boolean	Whether the object was saved. Always true for async - need to listen for "PFObjectSaveComplete" event.
function ParseLib:saveObj(obj, async)
	if async == nil then
		-- default to async save
		async = true
	end
	
	if async then
		-- block handler when background thread completes
		local handler = toobjc(
			function(succeeded, error)
				print("executing save block")
				local saveEvent = Event.new("PFObjectSaveComplete")
				saveEvent.success = succeeded
				saveEvent.error = error
				saveEvent.object = obj
				self.eventDispatcher:dispatchEvent(saveEvent)
			end):asVoidDyadicBlockBO()
		obj:saveInBackgroundWithBlock(handler)
		return true
	else
		return obj:save()
	end
end

-- set cache policy for queries
-- @param String	cache policy to use. One of ("ignoreCache", "cacheOnly", "networkOnly", "cacheElseNetwork", "networkElseCache", "cacheThenNetwork").
--					defaults to ignoreCache
-- @return Boolean	whether or not the cache policy was set
function ParseLib:setCachePolicy(policy)
	if policy == "ignoreCache" then
		self.cachePolicy = kPFCachePolicyIgnoreCache
	elseif policy == "cacheOnly" then
		self.cachePolicy = kPFCachePolicyCacheOnly
	elseif policy == "networkOnly" then
		self.cachePolicy = kPFCachePolicyNetworkOnly
	elseif policy == "cacheElseNetwork" then
		self.cachePolicy = kPFCachePolicyCacheElseNetwork
	elseif policy == "networkElseCache" then
		self.cachePolicy = kPFCachePolicyNetworkElseCache
	elseif policy == "cacheThenNetwork" then
		-- note: this will cause the PFQueryComplete event to fire twice, once for cache results, then once for network results
		self.cachePolicy = kPFCachePolicyCacheThenNetwork
	else
		print("Error: invalid value specified for cache policy.")
		return false
	end
	return true
end

-- set cache TTL for query results
-- note: Parse takes care of automatically flushing the cache if it takes up too much space
-- @param Number	age in seconds to cache results on disk
function ParseLib:setCacheTTL(age)
	self.maxCacheAge = age
end

-- clear query cache (for ALL queries)
function ParseLib:clearQueryCache()
	PFQuery:clearAllCachedResults()
end

-- query for PFObjects
-- valid query type values are: "equalTo", "notEqualTo", "lessThan", "lessThanOrEqualTo", "greaterThan", "greaterThanOrEqualTo", "containedIn", "notContainedIn"
-- @param String	className of the objects to query
-- @param Table		array of queries in the format {{where="keyname",type="equalTo",value="value"}{..}}
-- [@param] Table	key(s) to sort results on, in format {{type="asc",key="keyname"}{..}}. Valid types are "asc" and "desc".
-- [@param] Number	limit on the number of results to return. Must be between 1 and 1000.
-- @return Boolean	whether the query was valid. Always true for valid params - need to listen for "PFQueryComplete" event.
function ParseLib:query(className, queries, sortKey, limit)
	if not className or not queries or type(queries) ~= "table" then
		-- invalid parameters
		print("Error: bad parameters specified for query")
		return false
	end
	
	-- try and form the PFQuery object based on the params. If query is invalid, return false.
	local query = PFQuery:queryWithClassName(className)
	for i,v in ipairs(queries) do
		if v.where then
			if v.type == "equalTo" then
				query:whereKey_equalTo(v.where, v.value)
			elseif v.type == "notEqualTo" then
				query:whereKey_notEqualTo(v.where, v.value)
			elseif v.type == "lessThan" then
				query:whereKey_lessThan(v.where, v.value)
			elseif v.type == "lessThanOrEqualTo" then
				query:whereKey_lessThanOrEqualTo(v.where, v.value)
			elseif v.type == "greaterThan" then
				query:whereKey_greaterThan(v.where, v.value)
			elseif v.type == "greaterThanOrEqualTo" then
				query:whereKey_greaterThanOrEqualTo(v.where, v.value)
			elseif v.type == "containedIn" then
				-- v.value should be an array of values
				query:whereKey_containedIn(v.where, v.value)
			elseif v.type == "notContainedIn" then
				-- v.value should be an array of values
				query:whereKey_notContainedIn(v.where, v.value)
			else
				-- invalid query type
				print("Error: invalid type in query "..i)
				return false
			end
		else
			-- where key not specified
			print("Error: no where key specified")
			return false
		end
	end
	
	-- check for sort criteria {{type="asc", key="name"}}
	if sortKey and type(sortKey) == "table" then
		for i,v in ipairs(sortKey) do
			if v.type and v.key then
				if v.type == "asc" then
					if i == 1 then
						query:orderByAscending(v.key)
					else
						query:addAscendingOrder(v.key)
					end
				elseif v.type == "desc" then
					if i == 1 then
						query:orderByDescending(v.key)
					else
						query:addDescendingOrder(v.key)
					end
				end
			else
				print("Error: invalid sortKey params")
				return false
			end
		end
	end
	
	-- valid limits are 1 to 1000
	if limit and limit > 0 and limit < 1001 then
		query:setLimit(limit)
	end
	
	-- set cache policy
	if self.cachePolicy ~= nil then
		query:setCachePolicy(self.cachePolicy)
	end
	
	-- set cache TTL
	if self.maxCacheAge ~= nil then
		query:setMaxCacheAge(self.maxCacheAge)
	end
	
	-- block handler when background thread completes
	local handler = toobjc(
		function(objects, error)
			local queryEvent = Event.new("PFQueryComplete")
			queryEvent.objects = objects
			queryEvent.error = error
			--TODO: create a unique hash based on query params and return it above (and set in this event) so you can identify results.
			self.eventDispatcher:dispatchEvent(queryEvent)
		end):asVoidDyadicBlock()
	query:findObjectsInBackgroundWithBlock(handler)
	return true
end

-- get current PFUser
-- @return PFUser	The currently logged in user object, else nil
function ParseLib:currentUser()
	-- update current user object
	self.pfuser = PFUser:currentUser()
	return self.pfuser
end

-- get current PFUser username
-- @return String	The username of the currently logged in user, else blank
function ParseLib:username()
	-- update current user object
	self:currentUser()
	
	-- return username if found
	if self.pfuser then
		return self.pfuser:username()
	else
		return ""
	end
end

-- logout user
function ParseLib:logout()
	-- logout
	PFUser:logOut()
	
	-- update current user
	self:currentUser()
end

-- start social login / signup flow
-- @return Boolean	Whether or not the login flow started. If the user is already logged in, this would return false.
function ParseLib:startLogin()
	-- check if already logged in
	if self:currentUser() then
		-- already logged in
		local username = self:username()
		print("PFUser["..username.."] currently logged in")
		local alertTitle = "Welcome!"
		local alertMessage = "You are currently logged in as "..username
		local alertButton = "Logout"
		local alertView = UIAlertView:initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles(alertTitle, alertMessage, nil, alertButton, nil)
		alertView:show()
		print("logging user out so flow can be re-tested")
		self:logout()
		return false
	else
		-- display Parse login view
		self.loginView = DefaultSettingsViewController:init(self.eventDispatcher)
		getRootViewController():view():addSubview(self.loginView:view())
		return true
	end
end

-- test fetching data from a logged in Facebook user via Parse
-- requires the user to first be logged in using the social integration
-- @return Table	returns request user data as a table on success, else false if not a valid FB authorized user
function ParseLib:fbRequestTest()
	-- ensure current user is logged in and linked with FB
	self:currentUser()
	if not PFFacebookUtils:isLinkedWithUser(self.pfuser) then
		return false
	end
	
	-- stores userdata
	local user = {}

	-- Create request for user's Facebook data
    local requestPath = "me/?fields=name,location,gender,birthday,relationship_status"
     
    -- Send request to Facebook
    local request = PF_FBRequest:requestForGraphPath(requestPath)
	local handler = toobjc(
        function(connection, result, error)			
            if not error then
				print("Successful Graph Request")
				
                local userData = result
                user.facebookId = userData.id
				user.name = userData.name
				user.gender = userData.gender
				user.birthday = userData.birthday
				user.relationship = userData.relationship_status
				
				-- fetch profile image
				user.profileImageUrl = "https://graph.facebook.com/"..user.facebookId.."/picture?type=large&return_ssl_resources=1"
				
				print("fbID="..user.facebookId..", name="..user.name..", gender="..user.gender..", birthday="..user.birthday..", relationship="..user.relationship)
			else
				print("Graph API error")
				print(error)
            end
			return user
        end):asVoidTriadicBlock()
	request:startWithCompletionHandler(handler)
end

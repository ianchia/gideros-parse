--[[
ParseLib
- provides Lua hooks into the ParseSDK via BhWax
- dispatches "PFLoginComplete" event from ParseLib.eventDispatcher on successful login
- dispatches "PFLoginCancelled" event from ParseLib.eventDispatcher on login screen dismiss button click
- dispatches "PFObjectSaveComplete" event (with success, error, object fields) when an async object save is complete
- dispatches "PFQueryComplete" event (with error, objects fields) when a query has completed

Access Control Lists
It is also recommended to make use of default ACLs on any PFObjects. See https://www.parse.com/docs/ios_guide#security-recommendations/iOS
As per the recommendation, we have enabled automatic users and have set currentUser read/write as default settings, and provide readPerms and writePerms params to the createObj() function to help manage changes on a per object basis.

Push Notifications
Please follow the instructions in the Parse guide () to enable push notifications and register devices.
This includes adding the following in XCode:
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    ...
    // Register for push notifications
    [application registerForRemoteNotificationTypes: 
                                 UIRemoteNotificationTypeBadge |
                                 UIRemoteNotificationTypeAlert |             
                                 UIRemoteNotificationTypeSound];
    ...
}
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    // Store the deviceToken in the current Installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    [currentInstallation saveInBackground];
}
- (void)application:(UIApplication *)application 
didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [PFPush handlePush:userInfo];
}


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
-- [@param] String	Your Twitter consumer key
-- [@param] String	Your Twitter consumer secret
-- [@param] String	Cache policy to use for queries (see setCachePolicy function)
-- [@param] Number	Max age for query cache
function ParseLib:init(facebookAppId, twitterKey, twitterSecret, cachePolicy, cacheTTL)
	-- set automatic creation of anonymous users
	PFUser:enableAutomaticUser()	
	self.pfuser = self:currentUser()

	-- if an id hasn't been assigned (i.e. new user), save to Parse in order to assign an id
	if not self.pfuser:objectId() then
		print("Creating a new Anonymous PFUser")
		local handler = toobjc(function(succeeded, error)
			if error then
				print("Error saving anonymous user!")
				stats:error("errorSavingAnonUser")
			else
				print("Setting new user installation data")
				self.installation = PFInstallation:currentInstallation()
				self.installation:setObject_forKey(self:currentUser(), "user")
				self.installation:saveEventually()
			end
		end):asVoidDyadicBlockBO()
		self.pfuser:saveInBackgroundWithBlock(handler)
	else
		self.installation = PFInstallation:currentInstallation()
		if not self.installation:objectId() or not self.installation:objectForKey("user") then
			print("installation does not appear to have been saved. Saving...")
			self.installation:setObject_forKey(self:currentUser(), "user")
			self.installation:saveInBackground()
		end
	end

	-- setup facebook
	if facebookAppId then
		self.useFacebook = true
		PFFacebookUtils:initializeWithApplicationId(facebookAppId)
	else
		self.useFacebook = false
	end
	
	-- setup twitter
	if twitterKey and twitterSecret then
		self.useTwitter = true
		PFTwitterUtils:initializeWithConsumerKey_consumerSecret(twitterKey, twitterSecret)
	else
		self.useTwitter = false
	end
		
	-- set default cache policy (Parse default to "ignoreCache")
	if cachePolicy ~= nil then
		self:setCachePolicy(cachePolicy)
	end
	
	-- set default cache TTL
	if cacheTTL ~= nil then
		self:setCacheTTL(cacheTTL)
	end
		
	-- set default ACL for PFObjects to currentUser read/write only
	local defaultACL = PFACL:ACL()
	PFACL:setDefaultACL_withAccessForCurrentUser(defaultACL, true)
	
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
-- [@param] Table	An array of users who have read access to the object ("all", "none", userId, or userObj)
-- [@param] Table	An array of users who have write access to the object ("all", "none", userId, or userObj)
-- @return PFObject		The object for a given className
function ParseLib:createObj(className, readPerms, writePerms)
	local obj = PFObject:objectWithClassName(className)
	
	local acl = PFACL:ACL() -- creates a default ACL object with no permissions
	local aclCreated = false
	-- set read perms
	if readPerms ~= nil then
		if type(readPerms) == "table" then
			for k,v in ipairs(readPerms) do
				if type(v) == "string" then
					-- assume userId or "all" or "none"
					if v == "all" then
						acl:setPublicReadAccess(true)
					elseif v == "none" then
						acl:setPublicReadAccess(false)
					else
						acl:setReadAccess_forUserId(true, v)
					end
				else
					-- assume PFUser object
					acl:setReadAccess_forUser(true, v)
				end
				aclCreated = true
			end
		else
			-- invalid perms param
			print("Error: invalid read permissions set on object")
		end
	end
	-- set write perms
	if writePerms ~= nil then
		if type(writePerms) == "table" then
			for k,v in ipairs(writePerms) do
				if type(v) == "string" then
					-- assume userId or "all" or "none"
					if v == "all" then
						acl:setPublicWriteAccess(true)
					elseif v == "none" then
						acl:setPublicWriteAccess(false)
					else
						acl:setWriteAccess_forUserId(true, v)
					end
				else
					-- assume PFUser object
					acl:setWriteAccess_forUser(true, v)
				end
				aclCreated = true
			end
		else
			-- invalid perms param
			print("Error: invalid write permissions set on object")
		end	
	end
	if aclCreated then
		obj:setACL(acl)
	end
	
	return obj
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

-- refresh a PFObject from the serverAddress
-- @param PFObject	The object to refresh
function ParseLib:refresh(obj)
	if obj then
		obj:refresh()
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
-- note: Parse cache is a few megabytes and uses LRU ejection. It also takes care of automatically flushing the cache if it takes up too much space.
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
		local username = self.pfuser:username()
		if not username then
			username = ""
		end
		return username
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
-- @return Boolean	Whether or not the login flow started. If the user is already authenticated, this would return false.
function ParseLib:startLogin()
	-- check if already logged in and authenticated (not anon user)
	if self:currentUser() and self:currentUser():objectForKey("hasSetUsername") == 1 then
		-- already logged in
		local username = self:username()
		print("PFUser["..username.."] currently logged in")
		return false
	else
		if self:username() ~= "" then
			local username = self:username()
			print("Anonymous PFUser["..username.."] starting login")
		end
		
		-- display Parse login view
		self.loginView = DefaultSettingsViewController:init(self.eventDispatcher, {useFacebook=self.useFacebook, useTwitter=self.useTwitter, requestUsername=true, fbPermissions={"email"}})
		getRootViewController():view():addSubview(self.loginView:view())
		return true
	end
end

-- send a push notification to a target user
-- @param PFUser	The recipient of the push notification
-- @param Table		The data for the push notif {alert="push message", badge=3, sound="soundfilename"}. 
--					Badge can also be "Increment". Also, custom data can be set.
function ParseLib:sendPush(targetUser, data)
  -- create installation query
  local pushQuery = PFInstallation:query()
  if type(targetUser) == "string" then
	-- assume targetUser is a user objectId
	local userQuery = PFUser:query()
	userQuery:whereKey_equalTo("objectId", targetUser)
	pushQuery:whereKey_matchesQuery("user", userQuery)	 
  else
	-- assume targetUser is a PFUser object
	pushQuery:whereKey_equalTo("user", targetUser)
  end
  
  -- send push notification to query
  local push = PFPush:init()
  push:setQuery(pushQuery)
  push:setData(data)
  push:setPushToAndroid(false)
  push:sendPushInBackground()
end

-- set badge
-- @param Number	The current value of the icon badge for iOS apps
function ParseLib:setBadge(value)
	PFInstallation:currentInstallation():setBadge(value)
	PFInstallation:currentInstallation():saveInBackground()
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

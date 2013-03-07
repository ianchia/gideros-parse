--[[
ParseLib
- provides Lua hooks into the ParseSDK via BhWax
- dispatches "PFLoginComplete" event from ParseLib.eventDispatcher on successful login
- dispatches "PFLoginCancelled" event from ParseLib.eventDispatcher on login screen dismiss button click

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

ParseLib = Core.class()

-- init
function ParseLib:init(facebookAppId)
	self.facebookAppId = facebookAppId
	PFFacebookUtils:initializeWithApplicationId(self.facebookAppId)
	self.pfuser = self:currentUser()
	
	-- dispatcher for handling parse events
	myDis = Core.class(EventDispatcher)
	self.eventDispatcher = myDis.new()
end

-- set data in Parse
function ParseLib:set(className, key, value)
	-- ensure a className and key are set
	if not className or not key then
		return false
	end
	
	-- save key value to Parse
	local testObj = PFObject:objectWithClassName(className)
	testObj:setObject_forKey(value, key)
	testObj:save()
end

-- get current PFUser
function ParseLib:currentUser()
	-- update current user object
	self.pfuser = PFUser:currentUser()
	return self.pfuser
end

-- get current PFUser username
function ParseLib:username()
	-- update current user object
	self:currentUser()
	
	-- return username if found
	if self.pfuser then
		return self.pfuser:username()
	else
		return false
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
function ParseLib:fbRequest()
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

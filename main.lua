--[[
Parse integration for Gideros using BhWax
===================

This module provides social integration code for using the Parse SDK with Gideros, via BhWax.

You will need to have both BhWax and the Parse SDK for iOS setup for use with the Gidero iOS Player.

1) BhWax:
Wax (https://github.com/probablycorey/wax) is a Lua <-> Objective C bridge by Corey Johnson. A modified version of this for
use with Gideros (http://giderosmobile.com) was developed by Andy Bower called BhWax (https://github.com/bowerhaus/BhWax). 
You can read more about BhWax, including instructions on how to build the plugin, on Andy's blog post 
(http://bowerhaus.eu/blog/files/hot_wax.html).

2) Parse SDK for iOS:
a) Sign up at http://parse.com/
b) Follow the quick start guide provided by Parse (https://www.parse.com/apps/quickstart)
 - Select iOS, existing project, your app from downdown.
c) Note you should additionally set the XCode > Target > Build Settings > Other Linker Flags to use "-all_load -ObjC"
d) The code for the "Test the SDK" section is provided below. Just run the "parseSet()" function then confirm you have set it up correctly.

3) Set your Facebook App ID below.


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

-- set your Facebook appId here
fbAppId = "183814218409168"

require "DefaultSettingsViewController"

--
-- FUNCTIONS FOR TESTING PARSE INTEGRATION
--

-- test setting data to Parse
function parseSet(className, key, value)
	-- set testing defaults if not specified
	if not className then className = "TestObject" end
	if not key then key = "foo" end
	if not value then value = "bar" end
	
	-- save key value to Parse
	local testObj = PFObject:objectWithClassName(className)
	testObj:setObject_forKey(value, key)
	testObj:save()
end

-- test fetching data from a logged in Facebook user via Parse
-- requires the user to first be logged in using the social integration
function fbFetch()
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
        end):asVoidTriadicBlock()
        
	request:startWithCompletionHandler(handler)
end


--
-- MAIN
--

-- add a background with mouseup trigger for login/signup flow
local w, h=application:getContentWidth(), application:getContentHeight()
local bg=Shape.new()
bg:beginPath(Shape.NON_ZERO)
bg:setFillStyle(Shape.SOLID, 0xfeab00)
bg:moveTo(0, 0)
bg:lineTo(w, 0)
bg:lineTo(w, h)
bg:lineTo(0, h)
bg:lineTo(0, 0)
bg:endPath()
local font = TTFont.new("Tahoma.ttf", 72, true)
local loginText = TextField.new(font, "Tap to Start")
loginText:setPosition(w/2 - loginText:getWidth()/2, h/2 - loginText:getHeight()/2)
bg:addChild(loginText)
stage:addChild(bg)

function startParseFlow(button, event)
	event:stopPropagation()

	-- check if already logged in
	local puser = PFUser:currentUser()
	if puser then
		-- already logged in
		local username = puser:username()
		print("PFUser["..username.."] currently logged in")
		local alertTitle = "Welcome!"
		local alertMessage = "You are currently logged in as "..username
		local alertButton = "Logout"
		local alertView = UIAlertView:initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles(alertTitle, alertMessage, nil, alertButton, nil)
		alertView:show()
		print("logging user out so flow can be re-tested")
		PFUser:logOut()
	else
		-- display Parse login view
		defView = DefaultSettingsViewController:init()		
		getRootViewController():view():addSubview(defView:view())
	end
end

function removeStartListener()
	bg:removeEventListener(Event.MOUSE_UP, startParseFlow, bg)
end

function addStartListener()
	bg:addEventListener(Event.MOUSE_UP, startParseFlow, bg)
end

-- add tap to start listener
addStartListener()

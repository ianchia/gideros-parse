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
-- WAX Classes
--
waxClass({"DefaultSettingsViewController", UIViewController, protocols={"PFLogInViewControllerDelegate", "PFSignUpViewControllerDelegate"}})
waxClass({"CustomPFLogInViewController", PFLogInViewController})
waxClass({"CustomPFSignUpViewController", PFSignUpViewController})


--
-- DefaultSettingsViewController - main view controller
--
function DefaultSettingsViewController:init()
	self.super:init()
	return self
end

function DefaultSettingsViewController:viewDidAppear()
	self.super:viewDidAppear()
	
	local parseUser = PFUser:currentUser()
	if not parseUser then
		print("initializing view...")
		removeStartListener()
		-- view element enums
		local viewEnums = {none=0, userpass=1, forgotten=2, login=4, facebook=8, twitter=16, signup=32, dismiss=64, default=103}
		
		-- create login view controller
		local logInViewController = CustomPFLogInViewController:init()
		logInViewController:setDelegate(self)
		
		-- init for Facebook
		PFFacebookUtils:initializeWithApplicationId(fbAppId)
		local fbPerms = {"user_about_me", "user_location", "friends_about_me"}
		logInViewController:setFacebookPermissions(fbPerms)
		
		-- set UI buttons we want to display
		-- in this case, default plus Facebook
		logInViewController:setFields(viewEnums.userpass + viewEnums.login + viewEnums.facebook + viewEnums.signup + viewEnums.dismiss + viewEnums.forgotten)
		
		-- create the signup view controller
		local signUpViewController = CustomPFSignUpViewController:init()
		signUpViewController:setDelegate(self)
		logInViewController:setSignUpController(signUpViewController)
		
		-- display
		self:presentViewController_animated_completion(logInViewController, true, nil)
	end
end

--
-- LOG IN VIEW CONTROLLER DELEGATE
--

-- sent to the delegate to determine whether to submit login information
function DefaultSettingsViewController:logInViewController_shouldBeginLogInWithUsername_password(self, username, password)
	if not username or username == "" or not password or password == "" then
		-- display alert dialog
		print("fields were not filled out")
		local alertTitle = "Missing Information"
		local alertMessage = "Make sure you fill out all of the information!"
		local alertButton = "OK"
		local alertView = UIAlertView:initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles(alertTitle, alertMessage, nil, alertButton, nil)
		alertView:show()
		return false
	else
		return true
	end
end

-- sent to the delegate when the user is logged in
function DefaultSettingsViewController:logInViewController_didLogInUser(self, user)
	print("user successfully logged in!")
	local alertTitle = "Success!"
	local alertMessage = "You are now logged in."
	local alertButton = "OK"
	local alertView = UIAlertView:initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles(alertTitle, alertMessage, nil, alertButton, nil)
	alertView:show()
	-- reenable flow button
	addStartListener()
	
	-- hide login view
	self:view():removeFromSuperview()
	--self:dismissViewControllerAnimated_completion(true, nil)
end

-- sent to the delegate when the user fails to login
function DefaultSettingsViewController:logInViewController_didFailToLogInWithError(self, error)
	print("user failed to log in...")
end

function DefaultSettingsViewController:logInViewControllerDidCancelLogIn(self)
	print("user dismissed login view")
	-- hide login view
	addStartListener()
	self:view():removeFromSuperview()
end

--
-- SIGN UP VIEW CONTROLLER DELEGATE
--

-- sent to the delegate to determine whether to submit signup information
function DefaultSettingsViewController:signUpViewController_shouldBeginSignUp(self, info)
	local infoComplete = true
	
	-- loop through submitted data to ensure it was filled out before submitting
	for k,v in pairs(info) do
		if v == "" then
			infoComplete = false
			break
		end
	end
	
	if not infoComplete then
		print("fields were not filled out")
		-- display alert dialog
		local alertTitle = "Missing Information"
		local alertMessage = "Make sure you fill out all of the information!"
		local alertButton = "OK"
		local alertView = UIAlertView:initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles(alertTitle, alertMessage, nil, alertButton, nil)
		alertView:show()
	end
	
	return infoComplete
end

-- sent to the delegate when the signup is successful
function DefaultSettingsViewController:signUpViewController_didSignUpUser(self, user)
	print("user successfull signed up!")
	-- hide signup view
	self:dismissViewControllerAnimated_completion(true, nil)
end

-- sent to the delegate when the user signup fails
function DefaultSettingsViewController:signUpViewController_didFailToSignUpWithError(self, error)
	print("user failed to sign up...")
end

-- sent to the delegate when the user cancels the signup view
function DefaultSettingsViewController:signUpViewControllerDidCancelSignUp(self)
	print("user dismissed signup view")
	-- signup view will be hidden
end

--
-- CustomPFLogInViewController - allows custom control over display of UI elements for the login screen
--
function CustomPFLogInViewController:viewDidLoad()
	self.super:viewDidLoad()
	
	-- custom UI
	print("displaying custom login view")
	local signupText = "Sign Up Mate!"
	self:logInView():signUpButton():setTitle_forState(signupText, UIControlStateNormal)
	self:logInView():signUpButton():setTitle_forState(signupText, UIControlStateHighlighted)
end

function CustomPFLogInViewController:viewDidLayoutSubviews()
	-- custom button layout
	self:logInView():signUpButton():setFrame(CGRect(35,385,250,40))
end

--
-- CustomPFSignUpViewController - allows custom control over display of UI elements for the signup screen
--
function CustomPFSignUpViewController:viewDidLoad()
	self.super:viewDidLoad()
	
	-- custom UI
	print("displaying custom signup view")
	local signupText = "Sign Up Mate!"
	self:signUpView():signUpButton():setTitle_forState(signupText, UIControlStateNormal)
	self:signUpView():signUpButton():setTitle_forState(signupText, UIControlStateHighlighted)
end

function CustomPFLogInViewController:viewDidLayoutSubviews()
	-- custom button layout
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
		local defView = DefaultSettingsViewController:init()
		getRootViewController():view():addSubview(defView:view())
	end
end

function removeStartListener()
	bg:removeEventListener(Event.MOUSE_UP, startParseFlow, bg)
end

function addStartListener()
	bg:addEventListener(Event.MOUSE_UP, startParseFlow, bg)
end

addStartListener()
--parseSet()
--[[
Implements the DefaultSettingsViewController and customer login and signup views
- as per https://www.parse.com/tutorials/login-and-signup-views

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
	self:dismissViewControllerAnimated_completion(true, nil)
end

-- sent to the delegate when the user fails to login
function DefaultSettingsViewController:logInViewController_didFailToLogInWithError(self, error)
	print("user failed to log in...")
end

function DefaultSettingsViewController:logInViewControllerDidCancelLogIn(self)
	print("user dismissed login view")
	
	-- reenable flow button
	addStartListener()

	-- remove login view, else it'll autopop
	--self:view():removeFromSuperview()
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

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
function DefaultSettingsViewController:init(dispatcher, useFacebook, useTwitter)
	self.super:init()
	self.dismissed = false
	self.dispatcher = dispatcher
	self.useFacebook = useFacebook
	self.useTwitter = useTwitter
	return self
end

function DefaultSettingsViewController:viewDidAppear()
	self.super:viewDidAppear()
	self.pfuser = PFUser:currentUser()
	
	-- only display if it wasn't dismissed and the user either doesn't exist or is just anonymous
	if not self.dismissed and (not self.pfuser or PFAnonymousUtils:isLinkedWithUser(self.pfuser)) then
		print("initializing view...")
		-- view element enums
		local viewEnums = {none=0, userpass=1, forgotten=2, login=4, facebook=8, twitter=16, signup=32, dismiss=64, default=103}
		
		-- create login view controller
		self.logInViewController = CustomPFLogInViewController:init()
		self.logInViewController:setDelegate(self)
		
		-- init for Facebook
		if self.useFacebook then
			local fbPerms = {"user_about_me", "user_location", "friends_about_me"}
			self.logInViewController:setFacebookPermissions(fbPerms)
		end
		
		-- set UI buttons we want to display
		-- in this case, default plus Facebook and Twitter if enabled
		local viewDefaults = viewEnums.userpass + viewEnums.login + viewEnums.signup + viewEnums.dismiss + viewEnums.forgotten
		if self.useFacebook then
			viewDefaults = viewDefaults + viewEnums.facebook
		end
		if self.useTwitter then
			viewDefaults = viewDefaults + viewEnums.twitter
		end
		self.logInViewController:setFields(viewDefaults)
		
		-- create the signup view controller
		self.signUpViewController = CustomPFSignUpViewController:init()
		self.signUpViewController:setDelegate(self)
		self.logInViewController:setSignUpController(self.signUpViewController)
		
		-- display
		self:presentViewController_animated_completion(self.logInViewController, true, nil)
	end
end

function DefaultSettingsViewController:isViewVisible()
	if self:isViewLoaded() and self:view():window() then
		return true
	else
		return false
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

	-- hide login view
	local handler = toobjc(
        function()
            local completeEvent = Event.new("PFLoginComplete")
			self:delegate().dispatcher:dispatchEvent(completeEvent)
        end):asVoidNiladicBlock()
	
	self:dismissViewControllerAnimated_completion(true, handler)
end

-- sent to the delegate when the user fails to login
function DefaultSettingsViewController:logInViewController_didFailToLogInWithError(self, error)
	print("user failed to log in...")
end

function DefaultSettingsViewController:logInViewControllerDidCancelLogIn(self)
	print("user dismissed login view")
	-- mark as dismissed
	self:delegate().dismissed = true
	-- send cancelled event
	local completeEvent = Event.new("PFLoginCancelled")
	self:delegate().dispatcher:dispatchEvent(completeEvent)
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
	
	local imgPath = getPathForFile("|R|logo.png")
	local logoImg = UIImage:imageWithContentsOfFile(imgPath)
	if logoImg ~= nil then
		local imgView = UIImageView:initWithImage(logoImg)
		self:logInView():setLogo(imgView)
	end
	
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
	
	local imgPath = getPathForFile("|R|logo.png")
	local logoImg = UIImage:imageWithContentsOfFile(imgPath)
	if logoImg ~= nil then
		local imgView = UIImageView:initWithImage(logoImg)
		self:signUpView():setLogo(imgView)
	end
	
	local signupText = "Sign Up Mate!"
	self:signUpView():signUpButton():setTitle_forState(signupText, UIControlStateNormal)
	self:signUpView():signUpButton():setTitle_forState(signupText, UIControlStateHighlighted)
end

function CustomPFLogInViewController:viewDidLayoutSubviews()
	-- custom button layout
end

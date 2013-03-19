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
waxClass({"UsernameAlertView", UIAlertView, protocols={"UIAlertViewDelegate"}})

-- Username creation dialog
function UsernameAlertView:init(userObj)
	self.userObj = userObj
	self:initWithFrame()
	self:setDelegate(self)
	self:setTitle("Choose a Username")
	self:setMessage(" ")
	self:addButtonWithTitle("OK")
	local nameField = UITextField:initWithFrame(CGRect(20,45,245,25))
	nameField:setBackgroundColor(UIColor:whiteColor())
	nameField:becomeFirstResponder()
	local defaultUsername = "anon_" .. math.random(1000,9999)
	nameField:setText(defaultUsername)
	self.nameField = nameField
	self:addSubview(self.nameField)
	return self
end

function UsernameAlertView:alertView_clickedButtonAtIndex(idx)
	local text = self:delegate().nameField:text()
	if text ~= nil then
		print("Username inputted = "..text)
	end

	-- repop if empty input
	if text == "" then
		local newAlert = UsernameAlertView:init(self.userObj)
		newAlert:show()
	else
		print("querying if username already exists")
		local query = PFUser:query()
		query:whereKey_equalTo("username", text)
		local obj = query:getFirstObject()
		
		if not obj then
			-- save new username
			print("saving username")
			self.userObj:setUsername(text)
			self.userObj:setObject_forKey(1, "hasSetUsername")
			self.userObj:saveInBackground()
			
			-- show success alert
			local alertTitle = "Success!"
			local alertMessage = "You are now logged in."
			local alertButton = "OK"
			local alertView = UIAlertView:initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles(alertTitle, alertMessage, nil, alertButton, nil)
			alertView:show()
		else
			-- duplicate username
			print("duplicate username chosen")
			local alertTitle = "Try Again"
			local alertMessage = "Username already taken. Please try another."
			local alertButton = "OK"
			local alertView = UIAlertView:initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles(alertTitle, alertMessage, nil, alertButton, nil)
			alertView:show()
			
			local newAlert = UsernameAlertView:init(self.userObj)
			newAlert:show()
		end
	end
end
		
--
-- DefaultSettingsViewController - main view controller
--

-- init function
-- @param EventDispatcher	Dispatcher to send events login events back
-- [@param] Table		Array of config params:
--						useFacebook = Whether or not to use Facebook. Defaults false.
-- 						useTwitter = Whether or not to use Twitter. Defaults false.
--						requestUsername = Whether to request a username on successful social login. Defaults true.
--						logoImg = path to logo image to use
--						defaultView = table of login view UI items to show. e.g. {"userpass", "login", "signup"}. See default below.
function DefaultSettingsViewController:init(dispatcher, config)
	if not config then config = {} end
	
	self.super:init()
	self.dismissed = false
	self.dispatcher = dispatcher
	self.useFacebook = config.useFacebook or false
	self.useTwitter = config.useTwitter or false
	self.requestUsername = config.requestUsername or true
	self.logoImg = config.logoImg or "logo.png"
	self.fbPermissions = config.fbPermissions or {}
	self.defaultView = {"userpass","login","signup","dismiss","forgotten"}
	if self.useFacebook then
		self.defaultView[#self.defaultView+1] = "facebook"
	end
	if self.useTwitter then
		self.defaultView[#self.defaultView+1] = "twitter"
	end
	if config.defaultView then
		self.defaultView = config.defaultView
	end
	
	return self
end

function DefaultSettingsViewController:viewDidAppear()
	self.super:viewDidAppear()
	self.pfuser = PFUser:currentUser()
	
	-- only display if it wasn't dismissed and the user either doesn't exist or is just anonymous (hasn't set a username)
	-- NOTE: PFAnonymousUtils:isLinkedWithUser() seems to report incorrectly on anonymous status, so isn't being used
	if not self.dismissed and (not self.pfuser or self.pfuser:objectForKey("hasSetUsername") ~= 1) then
		print("initializing view...")
		
		-- view element enums
		local viewEnums = {none=0, userpass=1, forgotten=2, login=4, facebook=8, twitter=16, signup=32, dismiss=64, default=103}
		
		-- create login view controller
		self.logInViewController = CustomPFLogInViewController:init()
		self.logInViewController:setDelegate(self)
		
		-- init for Facebook
		if self.useFacebook then
			self.logInViewController:setFacebookPermissions(self.fbPermissions)
		end
		
		-- set UI buttons we want to display
		-- in this case, default plus Facebook and Twitter if enabled
		local viewDefaults = 0
		for i,v in ipairs(self.defaultView) do
			if v == "facebook" and self.useFacebook then
				viewDefaults = viewDefaults + viewEnums.facebook
			elseif v == "twitter" and self.useTwitter then
				viewDefaults = viewDefaults + viewEnums.twitter
			elseif viewEnums[v] ~= nil then
				viewDefaults = viewDefaults + viewEnums[v]
			end
		end
		self.logInViewController:setFields(viewDefaults)
		
		-- create the signup view controller
		self.signUpViewController = CustomPFSignUpViewController:init()
		self.signUpViewController:setDelegate(self)
		self.logInViewController:setSignUpController(self.signUpViewController)
		
		-- display
		self:presentViewController_animated_completion(self.logInViewController, true, nil)
	else
		if (stats) then
			stats:log("loginScreenNotShown", {objectId=tostring(self.pfuser:objectId())})
		end
	end
end

function DefaultSettingsViewController:isViewVisible()
	if self:isViewLoaded() and self:view():window() then
		return true
	else
		return false
	end
end

-- called after a successful signup
function DefaultSettingsViewController:successfulSignUp()
	-- also dismiss the login view after a sign up
	self.pfuser = PFUser:currentUser()
	self:logInViewController_didLogInUser(self.logInViewController, self.pfuser)
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

	local loginWithFacebook = PFFacebookUtils:isLinkedWithUser(user)
	local loginWithTwitter = PFTwitterUtils:isLinkedWithUser(user)
	
	if (stats) then
		stats:log("loginSuccess", {withFacebook=tostring(loginWithFacebook), withTwitter=tostring(loginWithTwitter)})
	end

	-- check if we should request a new username to go with social account
	if user:objectForKey("hasSetUsername") ~= 1 and self:delegate().requestUsername and (loginWithFacebook or loginWithTwitter) then	
		-- request a username to be set
		local alert = UsernameAlertView:init(user)
		alert:show()
	else
		-- just display a success dialog
		user:setObject_forKey(1, "hasSetUsername")
		user:saveInBackground()
		local alertTitle = "Success!"
		local alertMessage = "You are now logged in."
		local alertButton = "OK"
		local alertView = UIAlertView:initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles(alertTitle, alertMessage, nil, alertButton, nil)
		alertView:show()
	end
	
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
	if (stats) then
		stats:log("loginError", {error=tostring(error)})
	end
end

function DefaultSettingsViewController:logInViewControllerDidCancelLogIn(self)
	print("user dismissed login view")
	if (stats) then
		stats:log("clickDismissLoginScreen")
	end
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
	print("user successfully signed up!")
	if (stats) then
		stats:log("signupSuccess", {objectId=user:objectId()})
	end
	-- has set username
	user:setObject_forKey(1, "hasSetUsername")
	user:saveInBackground()
	-- hide signup and login view
	self:dismissViewControllerAnimated_completion(false, nil)
	self:delegate():successfulSignUp()
end

-- sent to the delegate when the user signup fails
function DefaultSettingsViewController:signUpViewController_didFailToSignUpWithError(self, error)
	print("user failed to sign up...")
	print(error)
	if (stats) then
		stats:log("signupError", {error=tostring(error)})
	end
end

-- sent to the delegate when the user cancels the signup view
function DefaultSettingsViewController:signUpViewControllerDidCancelSignUp(self)
	print("user dismissed signup view")
	if (stats) then
		stats:log("clickDismissSignupScreen")
	end
	-- signup view will be hidden
end

--
-- CustomPFLogInViewController - allows custom control over display of UI elements for the login screen
--
function CustomPFLogInViewController:viewDidLoad()
	self.super:viewDidLoad()
	
	if (stats) then
		stats:log("viewPageLoginScreen")
	end
	
	-- custom UI
	print("displaying custom login view")
	
	local imgPath = getPathForFile("|R|"..self:delegate().logoImg)
	local logoImg = UIImage:imageWithContentsOfFile(imgPath)
	if logoImg ~= nil then
		local imgView = UIImageView:initWithImage(logoImg)
		self:logInView():setLogo(imgView)
	end
	
	if self:logInView():signUpButton() then
		local signupText = "Create Account"
		self:logInView():signUpButton():setTitle_forState(signupText, UIControlStateNormal)
		self:logInView():signUpButton():setTitle_forState(signupText, UIControlStateHighlighted)
	end
end

function CustomPFLogInViewController:viewDidLayoutSubviews()
	-- custom button layout
	if self:logInView():signUpButton() then
		self:logInView():signUpButton():setFrame(CGRect(35,385,250,40))
	end
end

--
-- CustomPFSignUpViewController - allows custom control over display of UI elements for the signup screen
--
function CustomPFSignUpViewController:viewDidLoad()
	self.super:viewDidLoad()
	
	if (stats) then
		stats:log("viewPageSignupScreen")
	end
	
	-- custom UI
	print("displaying custom signup view")
	
	local imgPath = getPathForFile("|R|logo.png")
	local logoImg = UIImage:imageWithContentsOfFile(imgPath)
	if logoImg ~= nil then
		local imgView = UIImageView:initWithImage(logoImg)
		self:signUpView():setLogo(imgView)
	end
	
	local signupText = "Create Account"
	self:signUpView():signUpButton():setTitle_forState(signupText, UIControlStateNormal)
	self:signUpView():signUpButton():setTitle_forState(signupText, UIControlStateHighlighted)
end

function CustomPFLogInViewController:viewDidLayoutSubviews()
	-- custom button layout
end

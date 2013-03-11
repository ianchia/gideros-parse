--[[
Parse integration for Gideros using BhWax
===================

This module provides social integration code for using the Parse SDK with Gideros, via BhWax.

You will need to have both BhWax (the very latest code) and the Parse SDK for iOS setup for use with the Gidero iOS Player.

1) BhWax:
Wax (https://github.com/probablycorey/wax) is a Lua <-> Objective C bridge by Corey Johnson. A modified version of this for
use with Gideros (http://giderosmobile.com) was developed by Andy Bower called BhWax (https://github.com/bowerhaus/BhWax). 
You can read more about BhWax, including instructions on how to build the plugin, on Andy's blog post 
(http://bowerhaus.eu/blog/files/hot_wax.html).

2) Parse SDK for iOS:
a) Sign up at http://parse.com/
b) Follow the quick start guide provided by Parse (https://www.parse.com/apps/quickstart)
 - Select iOS, existing project, your app from downdown.
c) Add the following to ProtocolLoader.h (from BhWax):
		@protocol(PFLogInViewControllerDelegate) &&
        @protocol(PFSignUpViewControllerDelegate) &&
d) Note you should additionally set the XCode > Target > Build Settings > Other Linker Flags to use "-all_load -ObjC"
e) To confirm Parse is setup properly, run ParseLib:test(), then confirm on the Parse web site checker

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

require "ParseLib"

-- init Parse library
Parse = ParseLib.new(fbAppId)

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

-- login / signup flow functions
function bg:startParseFlow(event)
	event:stopPropagation()

	local started = Parse:startLogin()
	if started then
		removeStartListener()
	end
end

function bg:endParseFlow(event)
	event:stopPropagation()
	
	addStartListener()
end

function removeStartListener()
	if bg:hasEventListener(Event.MOUSE_UP) then
		bg:removeEventListener(Event.MOUSE_UP, bg.startParseFlow, bg)
	end
end

function addStartListener()
	if not bg:hasEventListener(Event.MOUSE_UP) then
		bg:addEventListener(Event.MOUSE_UP, bg.startParseFlow, bg)
	end
	if not Parse.eventDispatcher:hasEventListener("PFLoginComplete") then
		Parse.eventDispatcher:addEventListener("PFLoginComplete", bg.endParseFlow, bg)
	end
	if not Parse.eventDispatcher:hasEventListener("PFLoginCancelled") then
		Parse.eventDispatcher:addEventListener("PFLoginCancelled", bg.endParseFlow, bg)
	end
end

-- Test object creation functions
function endSave(handler, event)
	print("SAVE COMPLETED")
	Parse.eventDispatcher:removeEventListener("PFObjectSaveComplete", handler, handler)
	
	-- check for error
	if event.error then
		print(event.error)
	else
		print(event.success)
		print(event.object:objectId())
	end
end

function testObject()
	Parse.eventDispatcher:addEventListener("PFObjectSaveComplete", endSave, endSave)

	print("Saving 'TestObject' with name='Joe Blogs', level=23")
	local obj = Parse:createObj("TestObject")
	Parse:addToObj(obj, "name", "Joe Blogs")
	Parse:addToObj(obj, "level", 23)
	local success = Parse:saveObj(obj)
	print(success)
end

-- Test object query functions
function endQuery(handler, event)
	print("QUERY COMPLETED")
	Parse.eventDispatcher:removeEventListener("PFQueryComplete", handler, handler)
	
	-- check for error
	if event.error then
		-- Parse error, usually due to type mismatch on columns in query
		print(event.error)
	else
		-- output result info
		if type(event.objects) == "table" then
			print("Received "..#event.objects.." results:")
			for i,v in ipairs(event.objects) do
				print(v:objectId())
			end
		else
			print("No Results Received")
		end
	end
end

function testQuery()
	Parse.eventDispatcher:addEventListener("PFQueryComplete", endQuery, endQuery)
	print("SENDING QUERY...")
	local query = {
		{where="level", type="greaterThan", value=20},
		{where="name", type="equalTo", value="Joe Blogs"},
	}
	
	-- find objects matching query ordered by createdAt, limit 3 results
	local res = Parse:query("TestObject", query, {{type="desc",key="createdAt"}}, 3)
	print(res)
end

-- add tap to start listener for login / signup flow
addStartListener()

-- save an object
testObject()

-- query for objects
testQuery()

gideros-parse
=============

# Parse integration for Gideros using BhWax

This module provides social integration code for using the Parse SDK with Gideros, via BhWax.

You will need to have both BhWax and the Parse SDK for iOS setup for use with the Gidero iOS Player.

##1) BhWax:
Wax (https://github.com/probablycorey/wax) is a Lua <-> Objective C bridge by Corey Johnson. A modified version of this for
use with Gideros (http://giderosmobile.com) was developed by Andy Bower called BhWax (https://github.com/bowerhaus/BhWax). 

You can read more about BhWax, including instructions on how to build the plugin, on Andy's blog post 
(http://bowerhaus.eu/blog/files/hot_wax.html).

##2) Parse SDK for iOS:
a) Sign up at http://parse.com/

b) Follow the quick start guide provided by Parse (https://www.parse.com/apps/quickstart)

 - Select iOS, existing project, your app from downdown.

c) Note you should additionally set the XCode > Target > Build Settings > Other Linker Flags to use "-all_load -ObjC"

d) To confirm Parse is setup properly, run ParseLib:set("TestObject", "foo", "bar")

##3) Set your Facebook AppID in main.lua

At the top of main.lua, set "fbAppId" to your Facebook App ID

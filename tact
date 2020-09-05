#! /usr/local/bin/luajit
local module = arg[1] or "globe-main"

module = module:gsub("%.lua$", "") -- trim .lua

if type(LUA_PATH) ~= "string" then
	LUA_PATH = "common/?.lua"
end

LUA_PATH = module .. "/?.lua;" .. LUA_PATH
LUA_PATH = "?.lua;" .. LUA_PATH

dofile "extend.lua"

local chunk, path, message = locateloadfile(module)

if chunk then
	math.randomseed(os.time())
	chunk( )
else
	error(message)
end


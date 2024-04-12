local global  = _G
local api     = global.api
local table   = global.table
local require = global.require

--/ Module creation
local LonelyReach = module(...)

global.loadfile("LonelyReachLuaDatabase Loaded")

-- @brief add our custom managers to the ACSE database
LonelyReach.AddContentToCall = function(_tContentToCall)
	table.insert(_tContentToCall, require("Database.LonelyReach"))
end

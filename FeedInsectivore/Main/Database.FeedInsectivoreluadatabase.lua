local global  = _G
local api     = global.api
local table   = global.table
local require = global.require

--/ Module creation
local FeedInsectivore = module(...)

global.loadfile("FeedInsectivoreLuaDatabase Loaded")

-- @brief add our custom managers to the ACSE database
FeedInsectivore.AddContentToCall = function(_tContentToCall)
	table.insert(_tContentToCall, require("Database.FeedInsectivore"))
end

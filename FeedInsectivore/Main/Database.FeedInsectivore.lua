local global  = _G
local api     = global.api
local table   = global.table
local pairs   = global.pairs

--/ Module creation
local FeedInsectivoreData = module(...)

--/ Used as debug output for now
global.loadfile("Database.FeedInsectivore.lua Loaded")

--/ List of custom managers to force injection on a park
FeedInsectivoreData.tParkManagers  = {
	["Managers.FeedInsectivoreManager"] = {}
}

-- @brief Add our custom Manager to the park
FeedInsectivoreData.AddParkManagers = function(_fnAdd)
	local tData = FeedInsectivoreData.tParkManagers
	for sManagerName, tParams in pairs(tData) do
		_fnAdd(sManagerName, tParams)
	end
end

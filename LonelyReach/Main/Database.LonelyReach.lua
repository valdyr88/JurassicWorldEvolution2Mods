local global  = _G
local api     = global.api
local table   = global.table
local pairs   = global.pairs

--/ Module creation
local LonelyReachData = module(...)

--/ Used as debug output for now
global.loadfile("Database.LonelyReach.lua Loaded")

--/ List of custom managers to force injection on a park
LonelyReachData.tParkManagers  = {
	["Managers.LonelyReachManager"] = {}
}

-- @brief Add our custom Manager to the park
LonelyReachData.AddParkManagers = function(_fnAdd)
	local tData = LonelyReachData.tParkManagers
	for sManagerName, tParams in pairs(tData) do
		_fnAdd(sManagerName, tParams)
	end
end

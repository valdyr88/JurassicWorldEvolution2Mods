local global = _G
local api = global.api
local table = global.table
local require = require
local string = string
local LowerRangerDangerDatabaseConfig = module(...)
LowerRangerDangerDatabaseConfig.tConfig = {
	tLoad = {
		LowerRangerDanger = {sSymbol = "LowerRangerDanger"},
	}, 
	tCreateAndMerge = {
		Dinosaurs = {
			tChildrenToMerge = {"LowerRangerDanger"}
		}
	}
}

LowerRangerDangerDatabaseConfig.GetDatabaseConfig = function()
if not global.api.acse or global.api.acse.versionNumber < 0.641 then
    return {}
  else 
    return LowerRangerDangerDatabaseConfig.tConfig
  end
  
end


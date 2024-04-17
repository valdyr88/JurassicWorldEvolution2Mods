local global = _G
local api = global.api
local table = global.table
local require = require
local string = string
local ModDinoStatsDatabaseConfig = module(...)
ModDinoStatsDatabaseConfig.tConfig = {
	tLoad = {
		ModDinoStats = {sSymbol = "ModDinoStats"},
	}, 
	tCreateAndMerge = {
		Dinosaurs = {
			tChildrenToMerge = {"ModDinoStats"}
		}
	}
}

ModDinoStatsDatabaseConfig.GetDatabaseConfig = function()
if not global.api.acse or global.api.acse.versionNumber < 0.641 then
    return {}
  else 
    return ModDinoStatsDatabaseConfig.tConfig
  end
  
end


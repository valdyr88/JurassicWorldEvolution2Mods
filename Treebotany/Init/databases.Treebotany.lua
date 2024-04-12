local global = _G
local api = global.api
local table = global.table
local require = require
local string = string
local TreebotanyDatabaseConfig = module(...)
TreebotanyDatabaseConfig.tConfig = {
	tLoad = {
		Treebotany = {sSymbol = "Treebotany"},
	}, 
	tCreateAndMerge = {
		PaleoBotany = {
			tChildrenToMerge = {"Treebotany"}
		}
	}
}

TreebotanyDatabaseConfig.GetDatabaseConfig = function()
if not global.api.acse or global.api.acse.versionNumber < 0.641 then
    return {}
  else 
    return TreebotanyDatabaseConfig.tConfig
  end
  
end


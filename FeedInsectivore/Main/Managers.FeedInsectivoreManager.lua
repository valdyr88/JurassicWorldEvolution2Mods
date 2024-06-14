local global = _G
local api = global.api
local pairs = global.pairs
local require = global.require
local module = global.module
local math = global.math
local loadfile = global.loadfile
local type = type
local tostring = tostring
local table = require("Common.tableplus")
local Vector3 = require("Vector3")
local Quaternion = require("Quaternion")
local Object = require("Common.object")
local Mutators = require("Environment.ModuleMutators")

-----------------------------------------------------------------------------------------
local FeedInsectivoreManager= module(..., (Mutators.Manager)())
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.PrintConfigVars = function(self)
	global.api.debug.Trace("")
	global.api.debug.Trace("FeedInsectivoreManager values:")
	global.api.debug.Trace("")
	global.api.debug.Trace("	bLogAll: " .. tostring(self.bLogAll))
	global.api.debug.Trace("	bLogOnlyFavoriteDinos: " .. tostring(self.bLogOnlyFavoriteDinos))
	global.api.debug.Trace("	CheckForNewHungryDinosTime: " .. self.CheckForNewHungryDinosTime)
	global.api.debug.Trace("")
	for k,v in pairs(self.SpeciesInfo) do
		global.api.debug.Trace("	id: " .. k .. " = {")
		global.api.debug.Trace("		Species: " .. v.Species)
		global.api.debug.Trace("		HungerThreshold: " .. v.HungerThreshold)
		global.api.debug.Trace("		RemoveThreshold: " .. v.RemoveThreshold)
		global.api.debug.Trace("		FeedTimeDelayMin: " .. v.FeedTimeDelayMin)
		global.api.debug.Trace("		FeedTimeDelayMax: " .. v.FeedTimeDelayMax)
		global.api.debug.Trace("		FeedAmountMin: " .. v.FeedAmountMin)
		global.api.debug.Trace("		FeedAmountMax: " .. v.FeedAmountMax)
		global.api.debug.Trace("		IgnoreTime: " .. v.IgnoreTime)
		global.api.debug.Trace("	}")
	end
	global.api.debug.Trace("")
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.LoadVarsFromConfig = function(self)
	local vars = {
		bLogAll = false,
		bLogOnlyFavoriteDinos = true,
		CheckForNewHungryDinosTime = 30.0,
		FeedDinosInfo = {
			{
				Species = "Compsognathus",
				HungerThreshold = 0.45,
				RemoveThreshold = 0.85,
				FeedTimeDelayMin = 7,
				FeedTimeDelayMax = 15,
				FeedAmountMin = 0.01,
				FeedAmountMax = 0.15,
				FeedWaterContentFraction = 0.333,
				IgnoreTime = 5.0
			},
			{
				Species = "Coelophysis",
				HungerThreshold = 0.45,
				RemoveThreshold = 0.85,
				FeedTimeDelayMin = 7,
				FeedTimeDelayMax = 15,
				FeedAmountMin = 0.01,
				FeedAmountMax = 0.15,
				FeedWaterContentFraction = 0.333,
				IgnoreTime = 5.0
			},
			{
				Species = "MorosIntrepidus",
				HungerThreshold = 0.45,
				RemoveThreshold = 0.85,
				FeedTimeDelayMin = 7,
				FeedTimeDelayMax = 15,
				FeedAmountMin = 0.01,
				FeedAmountMax = 0.15,
				FeedWaterContentFraction = 0.333,
				IgnoreTime = 5.0
			},
			{
				Species = "Sinosauropteryx",
				HungerThreshold = 0.45,
				RemoveThreshold = 0.85,
				FeedTimeDelayMin = 7,
				FeedTimeDelayMax = 15,
				FeedAmountMin = 0.01,
				FeedAmountMax = 0.15,
				FeedWaterContentFraction = 0.333,
				IgnoreTime = 5.0
			},
			{
				Species = "Troodon",
				HungerThreshold = 0.45,
				RemoveThreshold = 0.85,
				FeedTimeDelayMin = 7,
				FeedTimeDelayMax = 15,
				FeedAmountMin = 0.01,
				FeedAmountMax = 0.15,
				FeedWaterContentFraction = 0.333,
				IgnoreTime = 5.0
			}
		}
	}
	
	local chunk, err = loadfile('Win64\\ovldata\\FeedInsectivore\\FeedInsectivoreConfig.lua', 'bt', vars)
	if not err then
		chunk()
	else
		global.api.debug.Trace("FeedInsectivore can't open config file")
	end
	
	self.bLogAll = vars.bLogAll
	self.bLogOnlyFavoriteDinos = vars.bLogAll == false and vars.bLogOnlyFavoriteDinos == true
	self.CheckForNewHungryDinosTime = vars.CheckForNewHungryDinosTime
	
	self.SpeciesInfo = {}
	for k,v in pairs(vars.FeedDinosInfo) do
		local speciesID = self.DinosAPI:GetSpeciesIDFromName(v.Species)
		global.api.debug.Trace("FeedInsectivore Adding: " .. v.Species .. " with id: " .. speciesID)
		if speciesID ~= nil and speciesID ~= 0 then
			self.SpeciesInfo[speciesID] = v
		end
	end
	
	self:PrintConfigVars()
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Initialize = function(self)
	self.hungryDinos = {}
	self.timer1 = 0.0
	
	self.bLogAll = false
	self.bLogOnlyFavoriteDinos = true
	
	self.bDeactivated = false
	self.bShutdown = false
	
	self.DinosaursDatabaseHelper = require("Helpers.DinosaursDatabaseHelper")
	self.RaycastUtils = require("Helpers.RaycastUtils")
	self.DinosAPI = api.world.GetWorldAPIs().dinosaurs
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Init = function(self, _tProperties, _tEnvironment)
	global.api.debug.Trace("acse Manager.FeedInsectivoreManager Init")
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.ReleaseArray = function(self)
	if self.hungryDinos ~= nil then
		for k, v in pairs(self.hungryDinos) do
			self.hungryDinos[k].location = nil
			self.hungryDinos[k] = nil
		end
	end
	self.hungryDinos = {}
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Activate = function(self)
	self:Initialize()
	self:LoadVarsFromConfig()
	
	self.bDeactivated = false
	self.bShutdown = false
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Deactivate = function(self)
	self:ReleaseArray()
	self.bDeactivated = true
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Shutdown = function(self)
	self:ReleaseArray()
	self.hungryDinos = nil
	self.bShutdown = true
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.CanBeInsectivore = function(self, speciesID)
	return self.SpeciesInfo[speciesID] ~= nil
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.GetSpeciesInfo = function(self, speciesID)
	return self.SpeciesInfo[speciesID]
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.ShouldLog = function(self, entityID)
	if self.bLogOnlyFavoriteDinos then
		return self.DinosAPI:IsDinosaurFavourited(entityID)
	else
		return self.bLogAll
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.ShouldAddToList = function(self, entityID)
	if entityID == nil or self.DinosAPI:IsDead(entityID) then
		return false
	end
	
	local nSpeciesID = self.DinosAPI:GetSpeciesID(entityID)
	local speciesInfo = self:GetSpeciesInfo(nSpeciesID)
	if speciesInfo == nil then
		return false
	end
	
	local tNeeds = self.DinosAPI:GetSatisfactionLevels(entityID)	
	return (tNeeds.Hunger < speciesInfo.HungerThreshold)
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.ShouldRemoveFromList = function(self, entityID)
	if entityID == nil or self.DinosAPI:IsDead(entityID) then
		return true
	end
	
	local nSpeciesID = self.DinosAPI:GetSpeciesID(entityID)
	local speciesInfo = self:GetSpeciesInfo(nSpeciesID)
	if speciesInfo == nil then
		if self.bLogAll or self.bLogOnlyFavoriteDinos then
			local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
			local sDinoName = api.ui.GetEntityName(entityID)
			global.api.debug.Trace("FeedInsectivore Can't find speciesInfo for dino in list! : " .. sSpeciesName .. " info for dino: " .. sDinoName)					
		end
		return true
	end
	
	local tNeeds = self.DinosAPI:GetSatisfactionLevels(entityID)	
	return (tNeeds.Hunger > speciesInfo.RemoveThreshold)
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.AddIfHungryDino = function(self, entityID)
	if not self:ShouldAddToList(entityID) then
		return
	end
	
	local nSpeciesID = self.DinosAPI:GetSpeciesID(entityID)
	local speciesInfo = self:GetSpeciesInfo(nSpeciesID)
	
	if speciesInfo == nil then
		return
	end
	
	local nextFeedDelay = math.random()*(speciesInfo.FeedTimeDelayMax - speciesInfo.FeedTimeDelayMin) + speciesInfo.FeedTimeDelayMin
	
	local entityInList = self.hungryDinos[entityID]
	if entityInList ~= nil and entityInList.key ~= nil then
		if entityInList.key == false then
			if entityInList.value < 0.1*self.CheckForNewHungryDinosTime then
				self.hungryDinos[entityID].key = true
				self.hungryDinos[entityID].value = nextFeedDelay
				
				if self:ShouldLog(entityID) then
					local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
					local sDinoName = api.ui.GetEntityName(entityID)
					global.api.debug.Trace("Hungry dino readded : " .. sSpeciesName .. " : " .. sDinoName)
				end
			end
		end
	else
		self.hungryDinos[entityID] = {}
		self.hungryDinos[entityID].key = true
		self.hungryDinos[entityID].value = nextFeedDelay
		
		if self:ShouldLog(entityID) then
			local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
			local sDinoName = api.ui.GetEntityName(entityID)
			global.api.debug.Trace("Hungry dino added : " .. sSpeciesName .. " : " .. sDinoName)
		end
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.UpdateHungryDinos = function(self, deltaTime)
    for entityID,v in pairs(self.hungryDinos) do
		if v ~= nil then
			if v.value ~= nil then
				if not self.DinosAPI:IsDead(entityID) then
					local oldValue = v.value
					v.value = v.value - deltaTime
					self.hungryDinos[entityID].value = v.value
					
					if v.key == true and oldValue >= 0.0 and v.value <= 0.0 then
						local speciesID = self.DinosAPI:GetSpeciesID(entityID)
						local speciesInfo = self:GetSpeciesInfo(speciesID)
						if speciesInfo ~= nil then
							local feedAmount = math.random()*(speciesInfo.FeedAmountMax-speciesInfo.FeedAmountMin) + speciesInfo.FeedAmountMin
							local nextFeedDelay = math.random()*(speciesInfo.FeedTimeDelayMax - speciesInfo.FeedTimeDelayMin) + speciesInfo.FeedTimeDelayMin
							self:FeedDino(entityID, feedAmount, feedAmount * speciesInfo.FeedWaterContentFraction, nextFeedDelay)
						end
					end
				end
			end
		end
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.CheckForNewHungryDinos = function(self)
    local parkDinos = self.DinosAPI:GetDinosaurs(false)
	
	for a,entityID in pairs(parkDinos) do
		self:AddIfHungryDino(entityID)
	end
	
	if self.bLogAll or self.bLogOnlyFavoriteDinos then
		local numLonely = 0
		for k,v in pairs(self.hungryDinos) do
			if v ~= nil then 
				if v.key == true then
					numLonely = numLonely + 1
				end
			end
		end
		global.api.debug.Trace("FeedInsectivoreManager.CheckForNewHungryDinos() num: " .. numLonely)
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.RemoveNonHungryDinos = function(self)
    for entityID,v in pairs(self.hungryDinos) do
		if v ~= nil then
			if v.key ~= nil and v.value ~= nil then 
				if v.key == true then
					if self:ShouldRemoveFromList(entityID) then
						self.hungryDinos[entityID].key = false
						
						if not self.DinosAPI:IsDead(entityID) then
							local speciesID = self.DinosAPI:GetSpeciesID(entityID)
							local speciesInfo = self:GetSpeciesInfo(speciesID)
							if speciesInfo ~= nil then
								self.hungryDinos[entityID].value = speciesInfo.IgnoreTime
							else
								self.hungryDinos[entityID].value = 60.0
							end
						else
							self.hungryDinos[entityID] = nil
						end
						
						if self:ShouldLog(entityID) then
							local nSpeciesID = self.DinosAPI:GetSpeciesID(entityID)
							local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
							local sDinoName = api.ui.GetEntityName(entityID)
							global.api.debug.Trace("Hungry dino removed " .. sSpeciesName .. ": " .. sDinoName)
						end
					end
				end
			end
		end
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.FeedDino = function(self, entityID, amount, waterAmount, nextTime)
	if not self.DinosAPI:IsDead(entityID) then
		-- api.motiongraph.SetEnumVariable(entityID, "Action", "Actions", "Eat")
		
		local tNeeds = self.DinosAPI:GetSatisfactionLevels(entityID)
		local newHunger = tNeeds.Hunger + amount
		local newThirst = tNeeds.Thirst + waterAmount
		newHunger = math.min(math.max(newHunger, 0.0), 1.0)
		newThirst = math.min(math.max(newThirst, 0.0), 1.0)
		self.DinosAPI:SetSatisfactionLevels(entityID, self.DinosAPI.DNT_Hunger, newHunger)
		self.DinosAPI:SetSatisfactionLevels(entityID, self.DinosAPI.DNT_Thirst, newThirst)
		
		self.hungryDinos[entityID].value = nextTime
		
		if self:ShouldLog(entityID) then
			local nSpeciesID = self.DinosAPI:GetSpeciesID(entityID)
			local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
			local sDinoName = api.ui.GetEntityName(entityID)
			global.api.debug.Trace("Hungry " .. sSpeciesName .. ": " .. sDinoName .. " started eating")
		end
	end
end
-----------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Advance = function(self, deltaTime)
	if (deltaTime == 0.0) or (self.hungryDinos == nil) or (self.bDeactivated == true) or (self.bShutdown == true) then
		return
	end
	
	self.timer1 = self.timer1 - deltaTime
	
	if self.timer1 < 0.0 then
		self.timer1 = self.CheckForNewHungryDinosTime
		self:CheckForNewHungryDinos()
	end
	
	self:UpdateHungryDinos(deltaTime)
	self:RemoveNonHungryDinos()
end
-----------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------
-- Validate the class methods/interfaces
(Mutators.VerifyManagerModule)(FeedInsectivoreManager)
-----------------------------------------------------------------------------------------

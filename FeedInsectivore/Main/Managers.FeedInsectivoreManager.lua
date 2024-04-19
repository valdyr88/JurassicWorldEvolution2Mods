local global = _G
local api = global.api
local pairs = global.pairs
local require = global.require
local module = global.module
local math = global.math
local type = type
local tostring = tostring
local table = require("Common.tableplus")
local Vector3 = require("Vector3")
local Quaternion = require("Quaternion")
local Object = require("Common.object")
local Mutators = require("Environment.ModuleMutators")
local DebugAPI = api.debug
local EntityAPI = api.entity
local PhysicsAPI = api.physics
local TransformAPI = api.transform
local DinosaursDatabaseHelper = require("Helpers.DinosaursDatabaseHelper")
local RaycastUtils = require("Helpers.RaycastUtils")

-----------------------------------------------------------------------------------------
local FeedInsectivoreManager= module(..., (Mutators.Manager)())
global.api.debug.Trace("acse Manager.FeedInsectivoreManager.lua loaded")
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Init = function(self, _tProperties, _tEnvironment)
	global.api.debug.Trace("acse Manager.FeedInsectivoreManager Init")

	self.worldAPIs  = api.world.GetWorldAPIs()
	self.xdlFlowMotionAPI = self.worldAPIs.xdlflowmotion
	self.dinosAPI = self.worldAPIs.dinosaurs
	self.hungryDinos = {}
	self.timer1 = 0.0
	
	self.CheckForNewHungryDinosTime = 30.0
	self.FeedTimeDelayMin = 7
	self.FeedTimeDelayMax = 15
	self.FeedAmountMin = 0.01
	self.FeedAmountMax = 0.15
	self.BaseIgnoreTime = 5.0
	
	self.bLog = false
	self.bLogOnlyFavoriteDinos = true
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.CanBeInsectivore = function(self, speciesName)
	if  speciesName == "Compsognathus" or
		speciesName == "Coelophysis" or
		speciesName == "MorosIntrepidus" or
		speciesName == "Sinosauropteryx" or
		speciesName == "Troodon" then
		return true
	end
	return false
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Advance = function(self, deltaTime)
	
	self.timer1 = self.timer1 - deltaTime
	
	if self.timer1 < 0 then
		self.timer1 = self.CheckForNewHungryDinosTime
		self:CheckForNewHungryDinos()
	end
	
	self:UpdateHungryDinos(deltaTime)
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Activate = function(self)
   self.hungryDinos = {}
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Deactivate = function(self)
   self.hungryDinos = nil
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.Shutdown = function(self)
   self.hungryDinos = nil
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.ShouldLog = function(self, entityID)
	if self.bLogOnlyFavoriteDinos then
		return self.dinosAPI:IsDinosaurFavourited(entityID)
	else
		return self.bLog
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.ShouldBeInList = function(self, entityID)
	
	if entityID == nil or self.dinosAPI:IsDead(entityID) then
		return false
	end
	
	local nSpeciesID = self.dinosAPI:GetSpeciesID(entityID)
	local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
	if not self:CanBeInsectivore(sSpeciesName) then
		return false
	end
	
	local tNeeds = self.dinosAPI:GetSatisfactionLevels(entityID)	
	return (tNeeds.Hunger < 0.45) --(tNeeds.Thirst < 0.125) or 
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.AddIfHungryDino = function(self, entityID, value)
	if not self:ShouldBeInList(entityID) then
		return
	end
	
	local entityInList = self.hungryDinos[entityID]
	if entityInList ~= nil and entityInList.key ~= nil and entityInList.key == false then
	   if entityInList.value < 0.1*self.CheckForNewHungryDinosTime then
			self.hungryDinos[entityID].key = true
			self.hungryDinos[entityID].value = value
			
			if self:ShouldLog(entityID) then
				local nSpeciesID = self.dinosAPI:GetSpeciesID(entityID)
				local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
				local sDinoName = api.ui.GetEntityName(entityID)
				global.api.debug.Trace("Hungry dino readded : " .. sSpeciesName .. " : " .. sDinoName)
			end
		end
		
		return
	end
	
	self.hungryDinos[entityID] = {}
	self.hungryDinos[entityID].key = true
	self.hungryDinos[entityID].value = value
	
	if self:ShouldLog(entityID) then
		local nSpeciesID = self.dinosAPI:GetSpeciesID(entityID)
		local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
		local sDinoName = api.ui.GetEntityName(entityID)
		global.api.debug.Trace("Hungry dino added : " .. sSpeciesName .. " : " .. sDinoName)
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.UpdateHungryDinos = function(self, deltaTime)
    for dinosaurEntity,v in pairs(self.hungryDinos) do
		if v ~= nil and v.value ~= nil and v.key == true and not self.dinosAPI:IsDead(dinosaurEntity) then
			local oldValue = v.value
			v.value = v.value - deltaTime
			self.hungryDinos[dinosaurEntity].value = v.value
			
			if oldValue >= 0.0 and v.value <= 0.0 then
				self:FeedDino(dinosaurEntity, math.random()*(self.FeedAmountMax-self.FeedAmountMin) + self.FeedAmountMin, math.random(self.FeedTimeDelayMin, self.FeedTimeDelayMax))
			end
		end
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.CheckForNewHungryDinos = function(self)
    local parkDinos = self.dinosAPI:GetDinosaurs(false)
	
	for a,dinosaurEntity in pairs(parkDinos) do
		self:AddIfHungryDino(dinosaurEntity, math.random(self.FeedTimeDelayMin, self.FeedTimeDelayMax))
	end
	
	if self.bLog then
		local numLonely = 0
		for k,v in pairs(self.hungryDinos) do
			if v ~= nil and v.key ~= nil and v.key == true then
				numLonely = numLonely + 1
			end
		end
		global.api.debug.Trace("FeedInsectivoreManager.CheckForNewHungryDinos() num: " .. numLonely)
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.RemoveNonHungryDinos = function(self)
    for dinosaurEntity,v in pairs(self.hungryDinos) do
		if (v ~= nil) and (v.key ~= nil and v.value ~= nil) and (v.key == true) then
			if not self:ShouldBeInList(dinosaurEntity) then
				
				self.hungryDinos[dinosaurEntity].key = false
				
				if not self.dinosAPI:IsDead(dinosaurEntity) then
					self.hungryDinos[dinosaurEntity].value = self.BaseIgnoreTime
				else
					self.hungryDinos[dinosaurEntity].value = math.huge
				end
				
				if self:ShouldLog(dinosaurEntity) then
					local nSpeciesID = self.dinosAPI:GetSpeciesID(dinosaurEntity)
					local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
					local sDinoName = api.ui.GetEntityName(dinosaurEntity)
					global.api.debug.Trace("Hungry dino removed " .. sSpeciesName .. ": " .. sDinoName)
				end
			end
		end
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.FeedDino = function(self, entityID, amount, nextTime)
	if not self.dinosAPI:IsDead(entityID) then
		-- api.motiongraph.SetEnumVariable(entityID, "Action", "Actions", "Eat")
		
		local tNeeds = self.dinosAPI:GetSatisfactionLevels(entityID)
		local newHunger = tNeeds.Hunger + amount
		newHunger = math.min(math.max(newHunger, 0.0), 1.0)
		self.dinosAPI:SetSatisfactionLevels(entityID, self.dinosAPI.DNT_Hunger, newHunger)
		
		self.hungryDinos[entityID].value = nextTime
		
		if self:ShouldLog(entityID) then
			local nSpeciesID = self.dinosAPI:GetSpeciesID(entityID)
			local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
			local sDinoName = api.ui.GetEntityName(entityID)
			global.api.debug.Trace("Hungry " .. sSpeciesName .. ": " .. sDinoName .. " started eating")
		end
	end
end
-----------------------------------------------------------------------------------------
FeedInsectivoreManager.CommandTravelTo = function(self, entityID, position)
	if not self.dinosAPI:IsDead(entityID) then
		-- global.api.debug.Trace("FeedInsectivoreManager.CommandTravelTo()")
		local tTransform = TransformAPI.GetTransform(entityID)
		api.motiongraph.SetEnumVariable(entityID, "Pace", "Paces", "Run")
		self.xdlFlowMotionAPI:TravelTo(entityID, tTransform:WithPos(position))
	end
end
-----------------------------------------------------------------------------------------
-- Validate the class methods/interfaces
(Mutators.VerifyManagerModule)(FeedInsectivoreManager)
-----------------------------------------------------------------------------------------

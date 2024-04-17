local global = _G
local api = global.api
local pairs = global.pairs
local require = global.require
local module = global.module
local math = global.math
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
local LonelyReachManager= module(..., (Mutators.Manager)())
global.api.debug.Trace("acse Manager.LonelyReachManager.lua loaded")
-----------------------------------------------------------------------------------------
LonelyReachManager.Init = function(self, _tProperties, _tEnvironment)
	global.api.debug.Trace("acse Manager.LonelyReachManager Init")

	self.worldAPIs  = api.world.GetWorldAPIs()
	self.xdlFlowMotionAPI = self.worldAPIs.xdlflowmotion
	self.dinosAPI = self.worldAPIs.dinosaurs
	self.lonelyDinos = {}
	self.timer1 = 0.0
	self.timer2 = 0.0
	
	self.CheckForNewLonelyDinosTime = 30.0
	self.RemoveNonLonelyDinosTime = 10.0
	self.IssueMovementCommandTime = 0.5
	self.IssueMovementCommandRndTime = 4.0
	self.MinDistanceThresholdSq = 48.0*48.0
	self.MaxTravelDistance = 150.0
	self.MaxTravelDistanceSq = self.MaxTravelDistance*self.MaxTravelDistance
	self.BaseIgnoreTime = 60.0
	
	self.bLog = true
end
-----------------------------------------------------------------------------------------
LonelyReachManager.Advance = function(self, deltaTime)
	
	self.timer1 = self.timer1 - deltaTime
	self.timer2 = self.timer2 - deltaTime
	
	if self.timer1 < 0 then
		self.timer1 = self.CheckForNewLonelyDinosTime
		self:CheckForNewLonelyDinos()
	end
	
	if self.timer2 < 0 then
		self.timer2 = self.RemoveNonLonelyDinosTime
		self:RemoveNonLonelyDinos()
	end
	
	self:UpdateLonelyTimers(deltaTime)
	self:IssueMovementCommands()
end
-----------------------------------------------------------------------------------------
LonelyReachManager.Activate = function(self)
   self.lonelyDinos = {}
end
-----------------------------------------------------------------------------------------
LonelyReachManager.Deactivate = function(self)
   self.lonelyDinos = nil
end
-----------------------------------------------------------------------------------------
LonelyReachManager.Shutdown = function(self)
   self.lonelyDinos = nil
end
-----------------------------------------------------------------------------------------
LonelyReachManager.ShouldBeInList = function(self, entityID)
	
	if entityID == nil or self.dinosAPI:IsDead(entityID) then
		return false
	end
	
	-- if not self.dinosAPI:IsDinosaur(nEntityID) then
		-- return false
	-- end
	
	local tNeeds = self.dinosAPI:GetSatisfactionLevels(entityID)
	
	-- if thirsty, hungry, sleepy then prioritise those
	if (tNeeds.Thirst < 0.5) or (tNeeds.Hunger < 0.5) or (tNeeds.Sleep < 0.2) then
		return false
	end
	
	if (tNeeds.Thirst < 0.75) or (tNeeds.Hunger < 0.75) or (tNeeds.Sleep < 0.25) then
		if math.random(0,100) < 50 then
			return false
		end
	end
	
    local tBio = self.dinosAPI:GetDinosaurBio(entityID)
	-- global.api.debug.Trace("thirst: " .. tNeeds.Thirst .. ", hunger; " .. tNeeds.Hunger)
	
	return tNeeds.HabitatSocial < tBio.nMinSocialThreshold
end
-----------------------------------------------------------------------------------------
LonelyReachManager.AddIfLonelyDino = function(self, entityID, value)
	if not self:ShouldBeInList(entityID) then
		return
	end
	
	local entityInList = self.lonelyDinos[entityID]
	if entityInList ~= nil and entityInList.key ~= nil and entityInList.key == false then
	   if entityInList.value < 0.0 then
			self.lonelyDinos[entityID].key = true
			self.lonelyDinos[entityID].value = value
			
			if self.bLog then
				local nSpeciesID = self.dinosAPI:GetSpeciesID(entityID)
				local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
				local sDinoName = api.ui.GetEntityName(entityID)
				global.api.debug.Trace("Lonely dino readded : " .. sSpeciesName .. " : " .. sDinoName)
			end
		end
		
		return
	end
	
	self.lonelyDinos[entityID] = {}
	self.lonelyDinos[entityID].key = true
	self.lonelyDinos[entityID].value = value
	self.lonelyDinos[entityID].location = Vector3:new(0, 0.1, 0)
	
	if self.bLog then
		local nSpeciesID = self.dinosAPI:GetSpeciesID(entityID)
		local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
		local sDinoName = api.ui.GetEntityName(entityID)
		global.api.debug.Trace("Lonely dino added : " .. sSpeciesName .. " : " .. sDinoName)
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.UpdateLonelyTimers = function(self, deltaTime)
    for dinosaurEntity,v in pairs(self.lonelyDinos) do
		if v ~= nil and v.value ~= nil then
			self.lonelyDinos[dinosaurEntity].value = v.value - deltaTime
		end
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CheckForNewLonelyDinos = function(self)
    local parkDinos = self.dinosAPI:GetDinosaurs(false)
	
	for a,dinosaurEntity in pairs(parkDinos) do
		self:AddIfLonelyDino(dinosaurEntity, 2.0)
	end
	
	if self.bLog then
		local numLonely = 0
		for k,v in pairs(self.lonelyDinos) do
			if v ~= nil and v.key ~= nil and v.key == true then
				numLonely = numLonely + 1
			end
		end
		global.api.debug.Trace("LonelyReachManager.CheckForNewLonelyDinos() num: " .. numLonely)
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.IssueMovementCommands = function(self)
	-- global.api.debug.Trace("LonelyReachManager.IssueMovementCommands()")
	
    for dinosaurEntity,v in pairs(self.lonelyDinos) do
		
		if v ~= nil and (v.key ~= nil and v.value ~= nil) and (v.key == true and v.value < 0.0) then
			local closestDino = self:FindClosestMemberOfSpecies(dinosaurEntity)
			
			if closestDino ~= nil then
				local lonelyPos = TransformAPI.GetTransform(dinosaurEntity):GetPos()
				local targetPos = TransformAPI.GetTransform(closestDino):GetPos()
				
				--limit travel distance
				-- local dX = targetPos:GetX() - lonelyPos:GetX()
				-- local dY = targetPos:GetY() - lonelyPos:GetY()
				-- local dZ = targetPos:GetZ() - lonelyPos:GetZ()
				local dPos = targetPos - lonelyPos
				local dX = dPos:GetX()
				local dY = dPos:GetY()
				local dZ = dPos:GetZ()
				local distanceSq = dX*dX + dY*dY + dZ*dZ
				if distanceSq > self.MaxTravelDistanceSq then
					local scaleDelta = self.MaxTravelDistance / math.sqrt(distanceSq)
					targetPos = Vector3:new(dX * scaleDelta + lonelyPos:GetX(),
											dY * scaleDelta + lonelyPos:GetY() + 1000.0,
											dZ * scaleDelta + lonelyPos:GetZ())
					local raytracePos = RaycastUtils.GetTerrainPositionUnderRaycast(targetPos, Vector3:new(0.0,-1.0,0.0))
					targetPos = Vector3:new(targetPos:GetX(),
											raytracePos:GetY(),
											targetPos:GetZ())
				end
				
				self:CommandTravelTo(dinosaurEntity, targetPos)
				
				if self.bLog then
					local nSpeciesID = self.dinosAPI:GetSpeciesID(dinosaurEntity)
					local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
					local sDinoName = api.ui.GetEntityName(dinosaurEntity)
					local sClosestDinoName = api.ui.GetEntityName(closestDino)
					
					local tNeeds = self.dinosAPI:GetSatisfactionLevels(dinosaurEntity)
					local tBio = self.dinosAPI:GetDinosaurBio(dinosaurEntity)
					
					-- local sDinoName = DinosaursDatabaseHelper.GetName(closestDino)
					global.api.debug.Trace("Lonely " .. sSpeciesName .. " " .. sDinoName .. ", moving to: " .. sClosestDinoName .. ", distance: " .. math.sqrt(distanceSq) .. " social: " .. tNeeds.HabitatSocial .. " < socialThr: " .. tBio.nMinSocialThreshold)
				end
			end
			
			self.lonelyDinos[dinosaurEntity].value = math.random() * self.IssueMovementCommandRndTime
														+ self.IssueMovementCommandTime
			
			-- local dinoPos = TransformAPI.GetTransform(dinosaurEntity):GetPos()
			-- local targetPos = Vector3:new(dinoPos:GetX() + 10, dinoPos:GetY(), dinoPos:GetZ())
			-- self:CommandTravelTo(dinosaurEntity, targetPos)
			-- self.lonelyDinos[dinosaurEntity].value = -1
		end
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CalcAddToListDowntime = function(self, entityID)
	local tNeeds = self.dinosAPI:GetSatisfactionLevels(entityID)
	-- check if thirsty, hungry, sleepy then ignore for a while
	
	if (tNeeds.Thirst < 0.1) or (tNeeds.Hunger < 0.1) then
		return 5.0*self.BaseIgnoreTime
	end
	
	if (tNeeds.Thirst < 0.33) or (tNeeds.Hunger < 0.33) or (tNeeds.Sleep < 0.1) then
		return 2.5*self.BaseIgnoreTime
	end
	
	if (tNeeds.Thirst < 0.5) or (tNeeds.Hunger < 0.5) or (tNeeds.Sleep < 0.25) then
		return self.BaseIgnoreTime
	end
	
	return 0.4*self.BaseIgnoreTime
end
-----------------------------------------------------------------------------------------
LonelyReachManager.RemoveNonLonelyDinos = function(self)
    for dinosaurEntity,v in pairs(self.lonelyDinos) do
		if (v ~= nil) and (v.key ~= nil and v.value ~= nil) and (v.key == true) then
			if not self:ShouldBeInList(dinosaurEntity) then
				
				self.lonelyDinos[dinosaurEntity].key = false
				
				if not self.dinosAPI:IsDead(dinosaurEntity) then
					self.lonelyDinos[dinosaurEntity].value = self:CalcAddToListDowntime(dinosaurEntity)
				else
					self.lonelyDinos[dinosaurEntity].value = math.huge
				end
				
				if self.bLog then
					local nSpeciesID = self.dinosAPI:GetSpeciesID(dinosaurEntity)
					local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
					local sDinoName = api.ui.GetEntityName(dinosaurEntity)
					global.api.debug.Trace("Lonely dino removed " .. sSpeciesName .. ": " .. sDinoName)
				end
			end
		end
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.FindClosestMemberOfSpecies = function(self, lonelyDino)
	if lonelyDino == nil or self.dinosAPI:IsDead(lonelyDino) then
		return nil
	end
	
    local parkDinos = self.dinosAPI:GetDinosaurs(false)
	local lonelySpecies = self.dinosAPI:GetSpeciesID(lonelyDino)
	local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(lonelySpecies)
	local lonelyPos = TransformAPI.GetTransform(lonelyDino):GetPos()
	local distance = math.huge
	
	local targetDino = nil
	
	for i = 1, #parkDinos do
		local otherDino = parkDinos[i]
		
		if (otherDino ~= lonelyDino) and (otherDino ~= nil) and 
		   (lonelySpecies == self.dinosAPI:GetSpeciesID(otherDino)) and 
		   not self.dinosAPI:IsDead(otherDino) then
			
			local otherDinoPos = TransformAPI.GetTransform(otherDino):GetPos()
			-- local dX = lonelyPos:GetX() - otherDinoPos:GetX()
			-- local dY = lonelyPos:GetY() - otherDinoPos:GetY()
			-- local dZ = lonelyPos:GetZ() - otherDinoPos:GetZ()
			local dPos = lonelyPos - otherDinoPos
			local dX = dPos:GetX()
			local dY = dPos:GetY()
			local dZ = dPos:GetZ()
			local newDistance = dX*dX + dY*dY + dZ*dZ
			
			if (newDistance < distance) and (newDistance > self.MinDistanceThresholdSq) then
				distance = newDistance
				targetDino = otherDino
			end
		end
	end
	
	if self.bLog then
		if targetDino == nil then
			global.api.debug.Trace("LonelyReachManager.FindClosestMemberOfSpecies() can't find other dino of " .. sSpeciesName)
		end
	end
	
	return targetDino
end
-----------------------------------------------------------------------------------------
LonelyReachManager.FindClosestGroupPosition = function(self, lonelyDino)
    local parkDinos = self.dinosAPI:GetDinosaurs(false)
	local lonelySpecies = self.dinosAPI:GetSpeciesID(lonelyDino)
	local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(lonelySpecies)
	local lonelyPos = TransformAPI.GetTransform(lonelyDino):GetPos()
	local listOfPositions = {}
	local distance = math.huge
	
	local targetDino = nil
	
	for i = 1, #parkDinos do
		local otherDino = parkDinos[i]
		
		if (otherDino ~= lonelyDino) and (otherDino ~= nil) and 
		   (lonelySpecies == self.dinosAPI:GetSpeciesID(otherDino)) and 
		   not self.dinosAPI:IsDead(otherDino) then
			
			local otherDinoPos = TransformAPI.GetTransform(otherDino):GetPos()
			
			listOfPositions[otherDino] = otherDinoPos
			
			-- local dX = lonelyPos:GetX() - otherDinoPos:GetX()
			-- local dY = lonelyPos:GetY() - otherDinoPos:GetY()
			-- local dZ = lonelyPos:GetZ() - otherDinoPos:GetZ()
			local dPos = lonelyPos - otherDinoPos
			local dX = dPos:GetX()
			local dY = dPos:GetY()
			local dZ = dPos:GetZ()
			local newDistance = dX*dX + dY*dY + dZ*dZ
			
			if (newDistance < distance) and (newDistance > self.MinDistanceThreshold) then
				distance = newDistance
				targetDino = otherDino
			end
		end
	end
	
	if self.bLog then
		if targetDino == nil then
			global.api.debug.Trace("LonelyReachManager.FindClosestMemberOfSpecies() can't find other dino of " .. sSpeciesName)
		end
	end
	
	return targetDino
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CommandTravelTo = function(self, entityID, position)
	if not self.dinosAPI:IsDead(entityID) then
		-- global.api.debug.Trace("LonelyReachManager.CommandTravelTo()")
		local tTransform = TransformAPI.GetTransform(entityID)
		api.motiongraph.SetEnumVariable(entityID, "Pace", "Paces", "Run")
		self.xdlFlowMotionAPI:TravelTo(entityID, tTransform:WithPos(position))
	end
end
-----------------------------------------------------------------------------------------
-- Validate the class methods/interfaces
(Mutators.VerifyManagerModule)(LonelyReachManager)
-----------------------------------------------------------------------------------------

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
	self.MinDistanceThreshold = 48.0
	self.MinDistanceThresholdSq = self.MinDistanceThreshold*self.MinDistanceThreshold
	self.MaxTravelDistance = 750.0
	self.MaxTravelDistanceSq = self.MaxTravelDistance*self.MaxTravelDistance
	self.ClosestNonLonelyRatio = 0.333
	self.ClosestNonLonelyRatioSq = self.ClosestNonLonelyRatio*self.ClosestNonLonelyRatio
	self.ClosestNonLonelyMaxDistance = 400.0
	self.ClosestNonLonelyMaxDistanceSq = self.ClosestNonLonelyMaxDistance*self.ClosestNonLonelyMaxDistance
	self.BaseIgnoreTime = 60.0
	
	self.bLog = true
	self.bLogOnlyFavoriteDinos = true
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
LonelyReachManager.ShouldLog = function(self, entityID)
	if self.bLogOnlyFavoriteDinos then
		return self.dinosAPI:IsDinosaurFavourited(entityID)
	else
		return self.bLog
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.IsDeadOrUnconcious = function(self, entityID)
	return self.dinosAPI:IsDead(entityID) or not self.dinosAPI:IsConscious(entityID)
end
-----------------------------------------------------------------------------------------
LonelyReachManager.ShouldBeInList = function(self, entityID)
	
	if entityID == nil or self:IsDeadOrUnconcious(entityID) then
		return false
	end
	
	if self.dinosAPI:IsHealthLowAndNotRecovering(entityID) then
		return false
	end
	
	local tNeeds = self.dinosAPI:GetSatisfactionLevels(entityID)
	
	-- if thirsty, hungry, sleepy then prioritise those
	if (tNeeds.Thirst < 0.6) or (tNeeds.Hunger < 0.5) or (tNeeds.Sleep < 0.00125) or (tNeeds.Stamina < 0.3) then
		return false
	end
	
    local tBio = self.dinosAPI:GetDinosaurBio(entityID)
	return tNeeds.HabitatSocial < tBio.nMinSocialThreshold
end
-----------------------------------------------------------------------------------------
LonelyReachManager.AddIfLonelyDino = function(self, entityID, value)
	if not self:ShouldBeInList(entityID) then
		return
	end
	
	local entityInList = self.lonelyDinos[entityID]
	
	if entityInList ~= nil then
	   if entityInList.key == false and entityInList.value < 0.0 then
			self.lonelyDinos[entityID].key = true
			self.lonelyDinos[entityID].value = value
			
			if self:ShouldLog(entityID) then
				local nSpeciesID = self.dinosAPI:GetSpeciesID(entityID)
				local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
				local sDinoName = api.ui.GetEntityName(entityID)
				global.api.debug.Trace("Lonely dino readded : " .. sSpeciesName .. " : " .. sDinoName)
			end
		end
		
	else
		self.lonelyDinos[entityID] = {}
		self.lonelyDinos[entityID].key = true
		self.lonelyDinos[entityID].value = value
		self.lonelyDinos[entityID].location = Vector3:new(0, 0.1, 0)
		self.lonelyDinos[entityID].count = 0
		
		if self:ShouldLog(entityID) then
			local nSpeciesID = self.dinosAPI:GetSpeciesID(entityID)
			local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
			local sDinoName = api.ui.GetEntityName(entityID)
			global.api.debug.Trace("Lonely dino added : " .. sSpeciesName .. " : " .. sDinoName)
		end
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.UpdateLonelyTimers = function(self, deltaTime)
    for dinosaurEntity,v in pairs(self.lonelyDinos) do
		if v ~= nil then
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
			if v ~= nil then
				if v.key == true then
					numLonely = numLonely + 1
				end
			end
		end
		global.api.debug.Trace("LonelyReachManager.CheckForNewLonelyDinos() num: " .. numLonely)
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CanIssueCommandsNow = function(self, entityID)
	return true
end
-----------------------------------------------------------------------------------------
LonelyReachManager.IssueMovementCommands = function(self)
	-- global.api.debug.Trace("LonelyReachManager.IssueMovementCommands()")
	
    for dinosaurEntity,v in pairs(self.lonelyDinos) do
		
		if (v ~= nil) then
			if (v.key == true and v.value < 0.0) and
			   (dinosaurEntity ~= nil) and not self:IsDeadOrUnconcious(dinosaurEntity) then
				
				local closestDino = self:FindClosestMemberOfSpecies(dinosaurEntity)
				
				if closestDino ~= nil then
					local lonelyPos = TransformAPI.GetTransform(dinosaurEntity):GetPos()
					local targetPos = TransformAPI.GetTransform(closestDino):GetPos()
					
					--limit travel distance
					local dPos = targetPos - lonelyPos
					local dX = dPos:GetX()
					local dY = dPos:GetY()
					local dZ = dPos:GetZ()
					local distanceSq = dX*dX + dY*dY + dZ*dZ
					if distanceSq > self.MaxTravelDistanceSq then
						local travelDistance = math.random() * (self.MaxTravelDistance - self.MinDistanceThreshold) + self.MinDistanceThreshold
						local scaleDelta = travelDistance / math.sqrt(distanceSq)
						targetPos = Vector3:new(dX * scaleDelta + lonelyPos:GetX(),
												dY * scaleDelta + lonelyPos:GetY() + 1000.0,
												dZ * scaleDelta + lonelyPos:GetZ())
						local raytracePos = RaycastUtils.GetTerrainPositionUnderRaycast(targetPos, Vector3:new(0.0,-1.0,0.0))
						targetPos = Vector3:new(targetPos:GetX(),
												raytracePos:GetY(),
												targetPos:GetZ())
					end
					
					self:CommandTravelTo(dinosaurEntity, targetPos)
					
					if self:ShouldLog(dinosaurEntity) then
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
				
				local cmdCount = self.lonelyDinos[dinosaurEntity].count
				if cmdCount > 0 then
					self.lonelyDinos[dinosaurEntity].count = cmdCount - 1
					self.lonelyDinos[dinosaurEntity].value = 0.25
				else
					self.lonelyDinos[dinosaurEntity].value = math.random() * self.IssueMovementCommandRndTime
															+ self.IssueMovementCommandTime
					self.lonelyDinos[dinosaurEntity].count = 20
				end
			end
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
	
	if (tNeeds.Thirst < 0.33) or (tNeeds.Hunger < 0.33) or (tNeeds.Sleep < 0.00125) or (tNeeds.Stamina < 0.1) then
		return 2.5*self.BaseIgnoreTime
	end
	
	if (tNeeds.Thirst < 0.5) or (tNeeds.Hunger < 0.5) or (tNeeds.Sleep < 0.0025) or (tNeeds.Stamina < 0.3) then
		return self.BaseIgnoreTime
	end
	
	return 0.4*self.BaseIgnoreTime
end
-----------------------------------------------------------------------------------------
LonelyReachManager.RemoveNonLonelyDinos = function(self)
	
    for dinosaurEntity,v in pairs(self.lonelyDinos) do
		if (v ~= nil) then
			if (v.key == true) then
				if not self:ShouldBeInList(dinosaurEntity) then
					
					self.lonelyDinos[dinosaurEntity].key = false
					
					if not self:IsDeadOrUnconcious(dinosaurEntity) then
						self.lonelyDinos[dinosaurEntity].value = self:CalcAddToListDowntime(dinosaurEntity)
					else
						self.lonelyDinos[dinosaurEntity] = nil
					end
					
					if self:ShouldLog(dinosaurEntity) and not self:IsDeadOrUnconcious(dinosaurEntity) then
						local nSpeciesID = self.dinosAPI:GetSpeciesID(dinosaurEntity)
						local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
						local sDinoName = api.ui.GetEntityName(dinosaurEntity)
						local tNeeds = self.dinosAPI:GetSatisfactionLevels(dinosaurEntity)
						-- (tNeeds.Thirst < 0.6) or (tNeeds.Hunger < 0.5) or (tNeeds.Sleep < 0.3) or (tNeeds.Stamina < 0.3)
						global.api.debug.Trace("Lonely dino removed " .. sSpeciesName .. ": " .. sDinoName .. ", Thirst: " .. tNeeds.Thirst .. ", Hunger: " .. tNeeds.Hunger .. ", Sleep: " .. tNeeds.Sleep .. ", Stamina: " .. tNeeds.Stamina)
					end
				end
			end
		end
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.FindClosestMemberOfSpecies = function(self, lonelyDino)
	if lonelyDino == nil or self:IsDeadOrUnconcious(lonelyDino) then
		return nil
	end
	
    local parkDinos = self.dinosAPI:GetDinosaurs(false)
	local lonelySpecies = self.dinosAPI:GetSpeciesID(lonelyDino)
	local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(lonelySpecies)
	local lonelyPos = TransformAPI.GetTransform(lonelyDino):GetPos()
	-- local distance = math.huge
	
	local closestNonLonely = nil
	local closestNonLonelyDistance = math.huge
	local closestLonely = nil
	local closestLonelyDistance = math.huge
	
	for i = 1, #parkDinos do
		local otherDino = parkDinos[i]
		
		if (otherDino ~= lonelyDino) and (otherDino ~= nil) and 
		   (lonelySpecies == self.dinosAPI:GetSpeciesID(otherDino)) and 
		   not self:IsDeadOrUnconcious(otherDino) then
			
			local tNeeds = self.dinosAPI:GetSatisfactionLevels(otherDino)
			local tBio = self.dinosAPI:GetDinosaurBio(otherDino)
			
			local otherDinoPos = TransformAPI.GetTransform(otherDino):GetPos()
			local dPos = lonelyPos - otherDinoPos
			local dX = dPos:GetX()
			local dY = dPos:GetY()
			local dZ = dPos:GetZ()
			local newDistance = dX*dX + dY*dY + dZ*dZ
			
			 --if non lonely other dino
			if (tNeeds.HabitatSocial > tBio.nMinSocialThreshold) then
				if (newDistance < closestNonLonelyDistance) then -- won't skip those that are min distance since our dino should stick to the non lonely dinos
					closestNonLonelyDistance = newDistance
					closestNonLonely = otherDino
				end
			else --lonely other dino, skipping those that are in min distance already
				if (newDistance < closestLonelyDistance) and (newDistance > self.MinDistanceThresholdSq) then
					closestLonelyDistance = newDistance
					closestLonely = otherDino
				end
			end
		end
	end
	
	local targetDino = closestNonLonely
	
	if (closestNonLonelyDistance > self.ClosestNonLonelyMaxDistanceSq) and (closestLonelyDistance < closestNonLonelyDistance) then
		local ratio = closestLonelyDistance / closestNonLonelyDistance
		if (ratio < self.ClosestNonLonelyRatioSq) then
			targetDino = closestLonely
		end
	end
	
	if self:ShouldLog(lonelyDino) then
		if targetDino == nil then
			global.api.debug.Trace("LonelyReachManager.FindClosestMemberOfSpecies() can't find other dino of " .. sSpeciesName)
		end
	end
	
	return targetDino
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CommandTravelTo = function(self, entityID, position)
	if not self:IsDeadOrUnconcious(entityID) then
		-- global.api.debug.Trace("LonelyReachManager.CommandTravelTo()")
		-- self.dinosAPI:ClearForcedBehaviourData(entityID)
		local tTransform = TransformAPI.GetTransform(entityID)
		-- api.motiongraph.SetEnumVariable(entityID, "Pace", "Paces", "Run")
		self.xdlFlowMotionAPI:TravelTo(entityID, tTransform:WithPos(position))
	end
end
-----------------------------------------------------------------------------------------
-- Validate the class methods/interfaces
(Mutators.VerifyManagerModule)(LonelyReachManager)
-----------------------------------------------------------------------------------------

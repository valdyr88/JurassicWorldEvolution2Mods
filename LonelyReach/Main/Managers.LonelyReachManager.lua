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
local XDLFlowMotionAPI = api.world.GetWorldAPIs().xdlflowmotion
local DinosAPI = api.world.GetWorldAPIs().dinosaurs

-----------------------------------------------------------------------------------------
local LonelyReachManager= module(..., (Mutators.Manager)())
global.api.debug.Trace("acse Manager.LonelyReachManager.lua loaded")
-----------------------------------------------------------------------------------------
LonelyReachManager.Init = function(self, _tProperties, _tEnvironment)
	global.api.debug.Trace("acse Manager.LonelyReachManager Init")
	
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
		return DinosAPI:IsDinosaurFavourited(entityID)
	else
		return self.bLog
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.IsDeadOrUnconcious = function(self, entityID)
	return DinosAPI:IsDead(entityID) or not DinosAPI:IsConscious(entityID)
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CommandTravelTo = function(self, entityID, position)
	if not self:IsDeadOrUnconcious(entityID) then
		local tTransform = TransformAPI.GetTransform(entityID)
		api.motiongraph.SetEnumVariable(entityID, "Pace", "Paces", "Run")
		XDLFlowMotionAPI:TravelTo(entityID, tTransform:WithPos(position))
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.ShouldBeInList = function(self, entityID)
	if entityID == nil or self:IsDeadOrUnconcious(entityID) then
		return false
	end
	
	if DinosAPI:IsHealthLowAndNotRecovering(entityID) then
		return false
	end
	
	local tNeeds = DinosAPI:GetSatisfactionLevels(entityID)
	-- if thirsty, hungry, sleepy then prioritise those
	if (tNeeds.Thirst < 0.6) or (tNeeds.Hunger < 0.5) or (tNeeds.Stamina < 0.3) then
		return false
	end
	
    local tBio = DinosAPI:GetDinosaurBio(entityID)
	return tNeeds.HabitatSocial < tBio.nMinSocialThreshold
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CalcAddToListDowntime = function(self, entityID)
	local tNeeds = DinosAPI:GetSatisfactionLevels(entityID)
	-- check if thirsty, hungry, sleepy then ignore for a while
	
	if (tNeeds.Thirst < 0.1) or (tNeeds.Hunger < 0.1) then
		return 2.0*self.BaseIgnoreTime
	end
	
	if (tNeeds.Thirst < 0.33) or (tNeeds.Hunger < 0.33) or (tNeeds.Stamina < 0.1) then
		return 1.5*self.BaseIgnoreTime
	end
	
	if (tNeeds.Thirst < 0.5) or (tNeeds.Hunger < 0.5) or (tNeeds.Stamina < 0.3) then
		return self.BaseIgnoreTime
	end
	
	return 0.4*self.BaseIgnoreTime
end
-----------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------
LonelyReachManager.FindClosestMemberOfSpecies = function(self, lonelyDino)
	if lonelyDino == nil or self:IsDeadOrUnconcious(lonelyDino) then
		return nil
	end
	
    local parkDinos = DinosAPI:GetDinosaurs(false)
	local lonelySpecies = DinosAPI:GetSpeciesID(lonelyDino)
	local lonelyPos = TransformAPI.GetTransform(lonelyDino):GetPos()
	
	local closestNonLonely = nil
	local closestNonLonelyDistance = math.huge
	local closestLonely = nil
	local closestLonelyDistance = math.huge
	
	for i = 1, #parkDinos do
		local otherDino = parkDinos[i]
		
		if (otherDino ~= lonelyDino) and (otherDino ~= nil) then
			if (lonelySpecies == DinosAPI:GetSpeciesID(otherDino)) then
				if (not self:IsDeadOrUnconcious(otherDino)) then
					
					local tNeeds = DinosAPI:GetSatisfactionLevels(otherDino)
					local tBio = DinosAPI:GetDinosaurBio(otherDino)
					
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
		end
	end
	
	local targetDino = closestNonLonely
	
	if (closestNonLonelyDistance > self.ClosestNonLonelyMaxDistanceSq) and (closestLonelyDistance < closestNonLonelyDistance) then
		local ratio = closestLonelyDistance / closestNonLonelyDistance
		if (ratio < self.ClosestNonLonelyRatioSq) then
			targetDino = closestLonely
		end
	end
	
	if targetDino == nil then
		if self:ShouldLog(lonelyDino) then
			local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(lonelySpecies)
			global.api.debug.Trace("LonelyReachManager.FindClosestMemberOfSpecies() can't find other dino of " .. sSpeciesName)
		end
	end
	
	return targetDino
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
				local nSpeciesID = DinosAPI:GetSpeciesID(entityID)
				local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
				local sDinoName = api.ui.GetEntityName(entityID)
				global.api.debug.Trace("Lonely dino readded : " .. sSpeciesName .. " : " .. sDinoName)
			end
		end
		
	else
		self.lonelyDinos[entityID] = {}
		self.lonelyDinos[entityID].key = true
		self.lonelyDinos[entityID].value = value
		self.lonelyDinos[entityID].location = Vector3:new(0.0, 0.0, 0.0)
		self.lonelyDinos[entityID].cmdCounter = 5
		
		if self:ShouldLog(entityID) then
			local nSpeciesID = DinosAPI:GetSpeciesID(entityID)
			local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
			local sDinoName = api.ui.GetEntityName(entityID)
			global.api.debug.Trace("Lonely dino added : " .. sSpeciesName .. " : " .. sDinoName)
		end
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CheckForNewLonelyDinos = function(self)
    local parkDinos = DinosAPI:GetDinosaurs(false)
	
	for a,entityID in pairs(parkDinos) do
		self:AddIfLonelyDino(entityID, 2.0)
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
LonelyReachManager.RemoveNonLonelyDinos = function(self)
	for entityID,v in pairs(self.lonelyDinos) do
		if (v ~= nil and entityID ~= nil) then
			if (v.key == true) then
				if not self:ShouldBeInList(entityID) then
					
					self.lonelyDinos[entityID].key = false
					
					if not self:IsDeadOrUnconcious(entityID) then
						self.lonelyDinos[entityID].value = self:CalcAddToListDowntime(entityID)
					else
						self.lonelyDinos[entityID] = nil
					end
					
					if self:ShouldLog(entityID) then
						if not DinosAPI:IsDead(entityID) then
							local nSpeciesID = DinosAPI:GetSpeciesID(entityID)
							local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
							local sDinoName = api.ui.GetEntityName(entityID)
							local tNeeds = DinosAPI:GetSatisfactionLevels(entityID)
							global.api.debug.Trace("Lonely dino removed " .. sSpeciesName .. ": " .. sDinoName .. ", Thirst: " .. tNeeds.Thirst .. ", Hunger: " .. tNeeds.Hunger .. ", Sleep: " .. tNeeds.Sleep .. ", Stamina: " .. tNeeds.Stamina)
						else
							local sDinoName = api.ui.GetEntityName(entityID)
							global.api.debug.Trace("Lonely dead dino removed " .. sDinoName)
							-- global.api.debug.Trace("Lonely dead dino removed, dinoID: " .. entityID)
						end
					end
				end
			end
		end
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.UpdateLonelyTimers = function(self, deltaTime)
    for entityID,v in pairs(self.lonelyDinos) do
		if v ~= nil then
			self.lonelyDinos[entityID].value = v.value - deltaTime
		end
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.IssueMovementCommands = function(self)
    for entityID,v in pairs(self.lonelyDinos) do
		if (entityID ~= nil and v ~= nil) then
			if (v.key == true and v.value < 0.0) then
				if not self:IsDeadOrUnconcious(entityID) then
					
					local closestDino = self:FindClosestMemberOfSpecies(entityID)
					if closestDino ~= nil then
						local lonelyPos = TransformAPI.GetTransform(entityID):GetPos()
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
						
						self:CommandTravelTo(entityID, targetPos)
						
						if self:ShouldLog(entityID) then
							local nSpeciesID = DinosAPI:GetSpeciesID(entityID)
							local sSpeciesName = DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
							local sDinoName = api.ui.GetEntityName(entityID)
							local sClosestDinoName = api.ui.GetEntityName(closestDino)
							
							local tNeeds = DinosAPI:GetSatisfactionLevels(entityID)
							local tBio = DinosAPI:GetDinosaurBio(entityID)
							
							global.api.debug.Trace("Lonely " .. sSpeciesName .. " " .. sDinoName .. ", moving to: " .. sClosestDinoName .. ", distance: " .. math.sqrt(distanceSq) .. " social: " .. tNeeds.HabitatSocial .. " < socialThr: " .. tBio.nMinSocialThreshold)
						end
					end
					
					local cmdCount = self.lonelyDinos[entityID].cmdCounter
					if cmdCount > 0 then
						self.lonelyDinos[entityID].cmdCounter = cmdCount - 1
						self.lonelyDinos[entityID].value = 0.25
					else
						self.lonelyDinos[entityID].value = math.random() * self.IssueMovementCommandRndTime
																+ self.IssueMovementCommandTime
						self.lonelyDinos[entityID].cmdCounter = 5
					end
				end
			end
		end
	end
end
-----------------------------------------------------------------------------------------

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

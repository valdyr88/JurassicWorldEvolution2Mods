local global = _G
local api = global.api
local pairs = global.pairs
local require = global.require
local module = global.module
local math = global.math
local loadfile = global.loadfile
local tostring = tostring
local table = require("Common.tableplus")
local Vector3 = require("Vector3")
local Quaternion = require("Quaternion")
local Object = require("Common.object")
local Mutators = require("Environment.ModuleMutators")

-----------------------------------------------------------------------------------------
local LonelyReachManager = module(..., (Mutators.Manager)())
-----------------------------------------------------------------------------------------
LonelyReachManager.PrintConfigVars = function(self)
	global.api.debug.Trace("")
	global.api.debug.Trace("LonelyReachManager loaded values from config:")
	global.api.debug.Trace("")
	global.api.debug.Trace("	bLogAll: " .. tostring(self.bLogAll))
	global.api.debug.Trace("	bLogOnlyFavoriteDinos: " .. tostring(self.bLogOnlyFavoriteDinos))
	global.api.debug.Trace("	CheckForNewLonelyDinosTime " .. self.CheckForNewLonelyDinosTime)
	global.api.debug.Trace("	RemoveNonLonelyDinosTime " .. self.RemoveNonLonelyDinosTime)
	global.api.debug.Trace("	IssueMovementCommandTime " .. self.IssueMovementCommandTime)
	global.api.debug.Trace("	IssueMovementCommandRndTime " .. self.IssueMovementCommandRndTime)
	global.api.debug.Trace("	MinDistanceThreshold " .. self.MinDistanceThreshold)
	global.api.debug.Trace("	MaxTravelDistance " .. self.MaxTravelDistance)
	global.api.debug.Trace("	ClosestNonLonelyRatio " .. self.ClosestNonLonelyRatio)
	global.api.debug.Trace("	ClosestNonLonelyMaxDistance " .. self.ClosestNonLonelyMaxDistance)
	global.api.debug.Trace("	BaseIgnoreTime " .. self.BaseIgnoreTime)
	global.api.debug.Trace("")
end
-----------------------------------------------------------------------------------------
LonelyReachManager.LoadVarsFromConfig = function(self)
	local vars = {
		bLogAll = false,
		bLogOnlyFavoriteDinos = true,
		CheckForNewLonelyDinosTime = 30.0,
		RemoveNonLonelyDinosTime = 10.0,
		IssueMovementCommandTime = 0.5,
		IssueMovementCommandRndTime = 4.0,
		CommandCount = 5,
		MinDistanceThreshold = 48.0,
		MaxTravelDistance = 750.0,
		ClosestNonLonelyRatio = 0.333,
		ClosestNonLonelyMaxDistance = 400.0,
		BaseIgnoreTime = 60.0
	}
	
	local chunk, err = loadfile('Win64\\ovldata\\LonelyReach\\LonelyReachConfig.lua', 'bt', vars)
	if not err then
		chunk()
	else
		global.api.debug.Trace("LonelyReachManager can't open config file")
	end
	
	self.bLogAll = vars.bLogAll
	self.bLogOnlyFavoriteDinos = vars.bLogAll == false and vars.bLogOnlyFavoriteDinos == true
	
	self.CheckForNewLonelyDinosTime = vars.CheckForNewLonelyDinosTime
	self.RemoveNonLonelyDinosTime =	vars.RemoveNonLonelyDinosTime
	self.IssueMovementCommandTime = vars.IssueMovementCommandTime
	self.IssueMovementCommandRndTime = vars.IssueMovementCommandRndTime
	self.CommandCount = vars.CommandCount
	self.MinDistanceThreshold = vars.MinDistanceThreshold
	self.MaxTravelDistance = vars.MaxTravelDistance
	self.ClosestNonLonelyRatio = vars.ClosestNonLonelyRatio
	self.ClosestNonLonelyMaxDistance = vars.ClosestNonLonelyMaxDistance
	self.BaseIgnoreTime = vars.BaseIgnoreTime
	
	self.MinDistanceThresholdSq = self.MinDistanceThreshold*self.MinDistanceThreshold
	self.MaxTravelDistanceSq = self.MaxTravelDistance*self.MaxTravelDistance
	self.ClosestNonLonelyRatioSq = self.ClosestNonLonelyRatio*self.ClosestNonLonelyRatio
	self.ClosestNonLonelyMaxDistanceSq = self.ClosestNonLonelyMaxDistance*self.ClosestNonLonelyMaxDistance
	
	self:PrintConfigVars()
end
-----------------------------------------------------------------------------------------
LonelyReachManager.Initialize = function(self)
	self.lonelyDinos = {}
	self.timer1 = 0.0
	self.timer2 = 0.0
	
	self.bLogAll = false
	self.bLogOnlyFavoriteDinos = true
	
	self.bDeactivated = false
	self.bShutdown = false
	
	self.DebugAPI = api.debug
	self.EntityAPI = api.entity
	self.PhysicsAPI = api.physics
	self.TransformAPI = api.transform
	self.DinosaursDatabaseHelper = require("Helpers.DinosaursDatabaseHelper")
	self.RaycastUtils = require("Helpers.RaycastUtils")
	self.XDLFlowMotionAPI = api.world.GetWorldAPIs().xdlflowmotion
	self.DinosAPI = api.world.GetWorldAPIs().dinosaurs
end
-----------------------------------------------------------------------------------------
LonelyReachManager.Init = function(self, _tProperties, _tEnvironment)
	global.api.debug.Trace("acse Manager.LonelyReachManager Init")
end
-----------------------------------------------------------------------------------------
LonelyReachManager.ReleaseArray = function(self)
	if self.lonelyDinos ~= nil then
		for k, v in pairs(self.lonelyDinos) do
			self.lonelyDinos[k].location = nil
			self.lonelyDinos[k] = nil
		end
	end
	self.lonelyDinos = {}
end
-----------------------------------------------------------------------------------------
LonelyReachManager.Activate = function(self)
	self:Initialize()
	self:LoadVarsFromConfig()
	self.bDeactivated = false
	self.bShutdown = false
end
-----------------------------------------------------------------------------------------
LonelyReachManager.Deactivate = function(self)
	self:ReleaseArray()
	self.lonelyDinos = {}
	self.bDeactivated = true
end
-----------------------------------------------------------------------------------------
LonelyReachManager.Shutdown = function(self)
	self:ReleaseArray()
	self.lonelyDinos = nil
	self.bShutdown = true
end
-----------------------------------------------------------------------------------------
LonelyReachManager.ShouldLog = function(self, entityID)
	if self.bLogOnlyFavoriteDinos then
		return self.DinosAPI:IsDinosaurFavourited(entityID)
	else
		return self.bLogAll
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.IsDeadOrUnconcious = function(self, entityID)
	return self.DinosAPI:IsDead(entityID) or not self.DinosAPI:IsConscious(entityID)
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CommandTravelTo = function(self, entityID, position)
	if not self:IsDeadOrUnconcious(entityID) then
		local tTransform = self.TransformAPI.GetTransform(entityID)
		api.motiongraph.SetEnumVariable(entityID, "Pace", "Paces", "Run")
		self.XDLFlowMotionAPI:TravelTo(entityID, tTransform:WithPos(position))
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.ShouldBeInList = function(self, entityID)
	if entityID == nil or self:IsDeadOrUnconcious(entityID) then
		return false
	end
	
	if self.DinosAPI:IsHealthLowAndNotRecovering(entityID) then
		return false
	end
	
	local tNeeds = self.DinosAPI:GetSatisfactionLevels(entityID)
	-- if thirsty, hungry, sleepy then prioritise those
	if (tNeeds.Thirst < 0.6) or (tNeeds.Hunger < 0.5) or (tNeeds.Stamina < 0.3) then
		return false
	end
	
    local tBio = self.DinosAPI:GetDinosaurBio(entityID)
	return tNeeds.HabitatSocial < tBio.nMinSocialThreshold
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CalcAddToListDowntime = function(self, entityID)
	local tNeeds = self.DinosAPI:GetSatisfactionLevels(entityID)
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
	
    local parkDinos = self.DinosAPI:GetDinosaurs(false)
	local lonelySpecies = self.DinosAPI:GetSpeciesID(lonelyDino)
	local lonelyPos = self.TransformAPI.GetTransform(lonelyDino):GetPos()
	
	local closestNonLonely = nil
	local closestNonLonelyDistance = math.huge
	local closestLonely = nil
	local closestLonelyDistance = math.huge
	
	for i = 1, #parkDinos do
		local otherDino = parkDinos[i]
		
		if (otherDino ~= lonelyDino) and (otherDino ~= nil) then
			if (lonelySpecies == self.DinosAPI:GetSpeciesID(otherDino)) then
				if (not self:IsDeadOrUnconcious(otherDino)) then
					
					local tNeeds = self.DinosAPI:GetSatisfactionLevels(otherDino)
					local tBio = self.DinosAPI:GetDinosaurBio(otherDino)
					
					local otherDinoPos = self.TransformAPI.GetTransform(otherDino):GetPos()
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
			local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(lonelySpecies)
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
				local nSpeciesID = self.DinosAPI:GetSpeciesID(entityID)
				local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
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
			local nSpeciesID = self.DinosAPI:GetSpeciesID(entityID)
			local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
			local sDinoName = api.ui.GetEntityName(entityID)
			global.api.debug.Trace("Lonely dino added : " .. sSpeciesName .. " : " .. sDinoName)
		end
	end
end
-----------------------------------------------------------------------------------------
LonelyReachManager.CheckForNewLonelyDinos = function(self)
    local parkDinos = self.DinosAPI:GetDinosaurs(false)
	
	for a,entityID in pairs(parkDinos) do
		self:AddIfLonelyDino(entityID, 2.0)
	end
	
	if self.bLogAll or self.bLogOnlyFavoriteDinos then
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
						if not self.DinosAPI:IsDead(entityID) then
							local nSpeciesID = self.DinosAPI:GetSpeciesID(entityID)
							local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
							local sDinoName = api.ui.GetEntityName(entityID)
							local tNeeds = self.DinosAPI:GetSatisfactionLevels(entityID)
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
						local lonelyPos = self.TransformAPI.GetTransform(entityID):GetPos()
						local targetPos = self.TransformAPI.GetTransform(closestDino):GetPos()
						
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
							local raytracePos = self.RaycastUtils.GetTerrainPositionUnderRaycast(targetPos, Vector3:new(0.0,-1.0,0.0))
							targetPos = Vector3:new(targetPos:GetX(),
													raytracePos:GetY(),
													targetPos:GetZ())
						end
						
						self:CommandTravelTo(entityID, targetPos)
						
						if self:ShouldLog(entityID) then
							local nSpeciesID = self.DinosAPI:GetSpeciesID(entityID)
							local sSpeciesName = self.DinosaursDatabaseHelper.GetNameForSpecies(nSpeciesID)
							local sDinoName = api.ui.GetEntityName(entityID)
							local sClosestDinoName = api.ui.GetEntityName(closestDino)
							
							local tNeeds = self.DinosAPI:GetSatisfactionLevels(entityID)
							local tBio = self.DinosAPI:GetDinosaurBio(entityID)
							
							global.api.debug.Trace("Lonely " .. sSpeciesName .. " " .. sDinoName .. ", moving to: " .. sClosestDinoName .. ", distance: " .. math.sqrt(distanceSq) .. " social: " .. tNeeds.HabitatSocial .. " < socialThr: " .. tBio.nMinSocialThreshold)
						end
					end
					
					local cmdCount = self.lonelyDinos[entityID].cmdCounter
					if cmdCount > 0 then
						self.lonelyDinos[entityID].cmdCounter = cmdCount-1
						self.lonelyDinos[entityID].value = 0.25
					else
						self.lonelyDinos[entityID].value = math.random() * self.IssueMovementCommandRndTime + self.IssueMovementCommandTime
						self.lonelyDinos[entityID].cmdCounter = self.CommandCount
					end
				end
			end
		end
	end
end
-----------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------
LonelyReachManager.Advance = function(self, deltaTime)
	if (deltaTime == 0.0) or (self.bDeactivated == true) or (self.bShutdown == true) then
		return
	end
	
	self.timer1 = self.timer1 - deltaTime
	self.timer2 = self.timer2 - deltaTime
	
	if self.timer1 < 0.0 then
		self.timer1 = self.CheckForNewLonelyDinosTime
		self:CheckForNewLonelyDinos()
	end
	
	if self.timer2 < 0.0 then
		self.timer2 = self.RemoveNonLonelyDinosTime
		self:RemoveNonLonelyDinos()
	end
	
	self:UpdateLonelyTimers(deltaTime)
	self:IssueMovementCommands()
end
-----------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------
-- Validate the class methods/interfaces
(Mutators.VerifyManagerModule)(LonelyReachManager)
-----------------------------------------------------------------------------------------
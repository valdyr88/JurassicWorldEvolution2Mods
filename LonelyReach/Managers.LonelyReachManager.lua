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

--/ Create module
local LonelyReachManager= module(..., (Mutators.Manager)())

global.api.debug.Trace("acse Manager.LonelyReachManager.lua loaded")

-- @Brief Init function for the LonelyReach mod
LonelyReachManager.Init = function(self, _tProperties, _tEnvironment)
	global.api.debug.Trace("acse Manager.LonelyReachManager Init")

	self.worldAPIs  = api.world.GetWorldAPIs()
	self.xdlFlowMotionAPI = self.worldAPIs.xdlflowmotion
	self.dinosAPI   = self.worldAPIs.dinosaurs
	self.weaponsAPI = self.worldAPIs.weapons
	self.messageAPI = global.api.messaging
	self.lonelyDinos = {}
	self.timer1 = 0
	self.timer2 = 0
	
	self.CheckForNewLonelyDinosTime = 30 --5min
	self.IssueMovementCommandsTime = 15
	self.IssueMovementCommandTime = 15 --120
	self.IssueMovementCommandRndTime = 0 --60
	self.MinDistanceThreshold = 50*50
	
end

-- @Brief Manages lonely dinos
LonelyReachManager.Advance = function(self, _nDeltaTime)
	
	self.timer1 = self.timer1 - _nDeltaTime
	self.timer2 = self.timer2 - _nDeltaTime
	
	if self.timer1 < 0 then
		self.timer1 = self.CheckForNewLonelyDinosTime
		self:CheckForNewLonelyDinos()
	end
	
	if self.timer2 < 0 then
		self.timer2 = self.IssueMovementCommandsTime
		self:RemoveNonLonelyDinos()
		self:IssueMovementCommands()
	end
	
    for dinosaurEntity,v in pairs(self.lonelyDinos) do
		if v ~= nil then
			self.lonelyDinos[dinosaurEntity] = v-_nDeltaTime
		end
	end
end

-- @Brief Called when the manager is activated
LonelyReachManager.Activate = function(self)
   self.lonelyDinos = {}
end

-- @Brief Called when the manager is deactivated
LonelyReachManager.Deactivate = function(self)
   self.lonelyDinos = nil
end

-- @Brief Called when the manager needs to be finished
LonelyReachManager.Shutdown = function(self)
   self.lonelyDinos = nil
end

-- @Brief Confirm a dinosaur is a valid target
LonelyReachManager.ShouldBeInList = function(self, entityID)
	-- if  self.dinosAPI:IsDinosaur(nEntityID) and
	-- not self.dinosAPI:IsDead(nEntityID) and
	-- not self.dinosAPI:IsLiveBait(nEntityID) and
	-- not self.dinosAPI:IsPterosaur(nEntityID) and
	-- not self.dinosAPI:IsAirborne(nEntityID) then
	
	if entityID == nil or self.dinosAPI:IsDead(entityID) then
		return false
	end
	
	local tNeeds = self.dinosAPI:GetSatisfactionLevels(entityID)
    local tBio = self.dinosAPI:GetDinosaurBio(entityID)
	
	if tNeeds["Population"] < tBio["Population"] then
		return true
	end
	
	return false
end

LonelyReachManager.CheckForNewLonelyDinos = function(self)
    local parkDinos = self.dinosAPI:GetDinosaurs(false)
	
	for i = 1, #parkDinos do
		local dinosaurEntity = parkDinos[i]
		if self:ShouldBeInList(dinosaurEntity) and self.lonelyDinos[dinosaurEntity] == nil then
			self.lonelyDinos[dinosaurEntity] =  math.random() * 25
		end
	end
	
	global.api.debug.Trace("LonelyReachManager.CheckForNewLonelyDinos() num: " .. tostring(#self.lonelyDinos))
end

LonelyReachManager.IssueMovementCommands = function(self)
    for dinosaurEntity,v in pairs(self.lonelyDinos) do
		if v ~= nil and v < 0 then
			local closestDino = self:FindClosestMemberOfSpecies(dinosaurEntity)
			if closestDino ~= nil then
				local targetPos = TransformAPI.GetTransform(closestDino):GetPos()
				self:CommandTravelTo(dinosaurEntity, targetPos)
			end
			self.lonelyDinos[dinosaurEntity] = math.random() * self.IssueMovementCommandRndTime + self.IssueMovementCommandTime
		end
	end
end

LonelyReachManager.RemoveNonLonelyDinos = function(self)
    for dinosaurEntity,v in pairs(self.lonelyDinos) do
		if v ~= nil then
			if not self:ShouldBeInList(dinosaurEntity) then			
				self.lonelyDinos[dinosaurEntity] = nil
			end
		end
	end
end

LonelyReachManager.FindClosestMemberOfSpecies = function(self, lonelyDino)
    local parkDinos = self.dinosAPI:GetDinosaurs(false)
	local lonelySpecies = self.dinosAPI:GetSpeciesID(lonelyDino)
	local lonelyPos = TransformAPI.GetTransform(lonelyDino):GetPos()
	local distance = 10000000
	
	local targetDino = nil
	
	for i = 1, #parkDinos do
		local otherDino = parkDinos[i]
		
		if otherDino ~= lonelyDino and lonelySpecies == self.dinosAPI:GetSpeciesID(otherDino) then
		
			local otherDinoPos = TransformAPI.GetTransform(lonelyDino):GetPos()
			local dX = lonelyPos:GetX() - otherDinoPos:GetX()
			local dY = lonelyPos:GetY() - otherDinoPos:GetY()
			local dZ = lonelyPos:GetZ() - otherDinoPos:GetZ()
			local newDisance = dX*dX + dY*dY + dZ*dZ
			
			if newDisance < distance and newDisance > self.MinDistanceThreshold then
				distance = newDisance
				targetDino = otherDino
			end
		end
	end
	
	if targetDino ~= nil then
		global.api.debug.Trace("LonelyReachManager.FindClosestMemberOfSpecies() found dino")
	end
	
	return targetDino
end

LonelyReachManager.CommandTravelTo = function(self, entityID, position)
	if not self.dinosAPI:IsDead(entityID) then
		global.api.debug.Trace("LonelyReachManager.CommandTravelTo()")
		local tTransform = TransformAPI.GetTransform(entityID)
		api.motiongraph.SetEnumVariable(entityID, "Pace", "Paces", "Run")
		self.xdlFlowMotionAPI:TravelTo(entityID, tTransform:WithPos(position))
	end
end

-- Validate the class methods/interfaces
(Mutators.VerifyManagerModule)(LonelyReachManager)



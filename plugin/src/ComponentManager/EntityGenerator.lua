local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Modules = script.Parent.Parent.Parent
local Constants = require(Modules.Anatta.Library.Core.Constants)
local Registry = require(Modules.Anatta.Library.World.Registry)
local Dom = require(Modules.Anatta.Library.Dom)

local CANDIDATE = ".__pendingAuthorityCandidate"
local PENDING_ENTITY_CREATION = ".__pendingEntityCreation"
local PENDING_ENTITY_DESTRUCTION = ".__pendingEntityDestruction"
local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local ENTITY_AUTHORITY = ".__entityAuthority"
local ENTITY_TAG_NAME = Constants.EntityTagName
local NEGOTIATION_ACK = ".__authorityNegotiation"
local TOKEN_ATTRIBUTE = "__authorityToken"
local PING_ATTRIBUTE = "__ping"

local EntityGenerator = {}
EntityGenerator.__index = EntityGenerator

local LocalPlayer = Players.LocalPlayer

function EntityGenerator.new()
	local self

	local authorityRemovedConnection = CollectionService:GetInstanceRemovedSignal(ENTITY_AUTHORITY):Connect(function()
		self:negotiateAuthority()
	end)

	self = setmetatable({
		heartbeatConnection = false,
		entityRemovedConnection = false,
		entityAddedConnection = false,
		pendingRemovals = {},
		pendingAdditions = {},
		authorityRemovedConnection = authorityRemovedConnection,
	}, EntityGenerator)

	if #CollectionService:GetTagged(ENTITY_AUTHORITY) == 0 then
		self:negotiateAuthority()
	end

	return self
end

function EntityGenerator:negotiateAuthority()
	if LocalPlayer == nil then
		self:becomeAuthority()
		return
	end

	LocalPlayer:SetAttribute(PING_ATTRIBUTE, LocalPlayer:GetNetworkPing())
	LocalPlayer:SetAttribute(TOKEN_ATTRIBUTE, Random.new():NextNumber())

	CollectionService:AddTag(LocalPlayer, NEGOTIATION_ACK)
	CollectionService:AddTag(LocalPlayer, CANDIDATE)

	repeat
		RunService.Heartbeat:Wait()
	until #CollectionService:GetTagged(NEGOTIATION_ACK) == #CollectionService:GetTagged(CANDIDATE)
		or #CollectionService:GetTagged(ENTITY_AUTHORITY) > 0

	if #CollectionService:GetTagged(ENTITY_AUTHORITY) > 0 then
		return
	end

	local candidates = {}

	for _, player in ipairs(CollectionService:GetTagged(CANDIDATE)) do
		table.insert(candidates, {
			player = player,
			ping = player:GetAttribute(PING_ATTRIBUTE),
			token = player:GetAttribute(TOKEN_ATTRIBUTE),
		})
	end

	-- The client with the least latency to the TC server should be the authority.
	table.sort(candidates, function(lhs, rhs)
		return lhs.ping < rhs.ping
	end)

	local lowest = candidates[1]
	local finalCandidates = {}

	-- In the exceedingly unlikely [?] event that two or more clients report exactly
	-- equal pings...
	for _, candidate in ipairs(candidates) do
		if candidate.ping == lowest.ping then
			table.insert(finalCandidates, candidate)
		end
	end

	-- ...we'll sort further by the randomly-generated token.
	table.sort(finalCandidates, function(lhs, rhs)
		return lhs.token < rhs.token
	end)

	local chosen = finalCandidates[1]

	if chosen.player == LocalPlayer then
		self:becomeAuthority()
	end
end

function EntityGenerator:becomeAuthority()
	local registry = Registry.new()

	local function add(instance)
		CollectionService:AddTag(instance, ENTITY_TAG_NAME)
		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, registry:createEntity())
		CollectionService:RemoveTag(instance, PENDING_ENTITY_DESTRUCTION)
		CollectionService:RemoveTag(instance, PENDING_ENTITY_CREATION)

		ChangeHistoryService:ResetWaypoints()
	end

	local function remove(instance)
		local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

		if registry:entityIsValid(entity) then
			registry:destroyEntity(instance:GetAttribute(ENTITY_ATTRIBUTE_NAME))
		end

		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)
		CollectionService:RemoveTag(instance, ENTITY_TAG_NAME)
		CollectionService:RemoveTag(instance, PENDING_ENTITY_CREATION)
		CollectionService:RemoveTag(instance, PENDING_ENTITY_DESTRUCTION)
	end

	Dom.getEntitiesFromDom(registry)

	self.heartbeatConnection = RunService.Heartbeat:Connect(function()
		local pendingAdditions = CollectionService:GetTagged(PENDING_ENTITY_CREATION)
		local pendingDestructions = CollectionService:GetTagged(PENDING_ENTITY_DESTRUCTION)

		if
			next(pendingAdditions) == nil
			and next(pendingDestructions) == nil
			and next(self.pendingRemovals) == nil
			and next(self.pendingAdditions) == nil
		then
			return
		end

		for _, instance in ipairs(pendingAdditions) do
			add(instance)
		end

		for instance in pairs(self.pendingAdditions) do
			add(instance)
		end

		for _, instance in ipairs(pendingDestructions) do
			remove(instance)
		end

		for instance in pairs(self.pendingRemovals) do
			remove(instance)
		end

		table.clear(self.pendingRemovals)
		table.clear(self.pendingAdditions)
	end)

	self.entityRemovedConnection = CollectionService
		:GetInstanceRemovedSignal(ENTITY_TAG_NAME)
		:Connect(function(instance)
			if instance:GetAttribute(ENTITY_ATTRIBUTE_NAME) ~= nil then
				self.pendingRemovals[instance] = true
			end
		end)

	self.entityAddedConnection = CollectionService:GetInstanceAddedSignal(ENTITY_TAG_NAME):Connect(function(instance)
		self.pendingAdditions[instance] = true
	end)
end

function EntityGenerator:requestCreation(instance)
	if CollectionService:HasTag(instance, ENTITY_TAG_NAME) then
		return
	end

	CollectionService:AddTag(instance, PENDING_ENTITY_CREATION)
end

function EntityGenerator:requestDestruction(instance)
	if not CollectionService:HasTag(instance, ENTITY_TAG_NAME) then
		return
	end

	CollectionService:AddTag(instance, PENDING_ENTITY_DESTRUCTION)
end

function EntityGenerator:destroy()
	self.authorityRemovedConnection:Disconnect()
	self.entityRemovedConnection:Disconnect()
	self.entityAddedConnection:Disconnect()

	if self.heartbeatConnection then
		self.heartbeatConnection:Disconnect()
	end
end

return EntityGenerator

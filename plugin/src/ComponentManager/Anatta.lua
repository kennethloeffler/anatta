local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent.Parent.Parent

local Dom = require(Modules.Anatta.Library.Dom)
local Constants = require(Modules.Anatta.Library.Core.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

local Anatta = {}

local definitions = setmetatable({}, { __mode = "k" })

local function getValidEntity(world, instance)
	local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

	if
		entity == nil
		or typeof(entity) ~= "number"
		or not world.registry:entityIsValid(entity)
	then
		entity = world.registry:createEntity()
		CollectionService:AddTag(instance, ".anattaInstance")
		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)
	end

	return entity
end

local function getAttributeMap(instance, definition)
	if definitions[definition] then
		return true, next(definitions[definition])
	end

	local defaultSuccess, default = definition.type:tryDefault()

	if not defaultSuccess then
		return false, default
	end

	local attributeSuccess, attributeMap = Dom.tryToAttributes(instance, 0, definition, default)

	if not attributeSuccess then
		return false, attributeMap
	end

	definitions[definition] = { [attributeMap] = default }

	return true, attributeMap, default
end

function Anatta.addComponent(world, instance, definition)
	local entity = getValidEntity(world, instance)
	local success, attributeMap, defaultValue = getAttributeMap(instance, definition)

	if not success then
		return false, attributeMap
	end

	attributeMap[ENTITY_ATTRIBUTE_NAME] = entity
	world.registry:addComponent(entity, definition, defaultValue)

	for attributeName, attributeValue in pairs(attributeMap) do
		instance:SetAttribute(attributeName, attributeValue)
	end

	CollectionService:AddTag(instance, definition.name)

	return true
end

function Anatta.removeComponent(world, instance, definition)
	local entity = getValidEntity(world, instance)
	local success, attributeMap = getAttributeMap(instance, definition)

	if not success then
		return false, attributeMap
	end

	world.registry:tryRemoveComponent(entity, definition)

	for attributeName in pairs(attributeMap) do
		if attributeName ~= ENTITY_ATTRIBUTE_NAME then
			instance:SetAttribute(attributeName, nil)
		end
	end

	if world.registry:entityIsOrphaned(entity) then
		CollectionService:RemoveTag(instance, ".anattaInstance")
		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)
	end

	CollectionService:RemoveTag(instance, definition.name)

	return true
end

return Anatta

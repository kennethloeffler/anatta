local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent.Parent.Parent

local Dom = require(Modules.Anatta.Library.Dom)
local Constants = require(Modules.Anatta.Library.Core.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local SHARED_INSTANCE_TAG_NAME = Constants.SharedInstanceTagName

local Anatta = {}

local function getValidEntity(world, instance)
	local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

	if
		entity == nil
		or typeof(entity) ~= "number"
		or not world.registry:entityIsValid(entity)
	then
		entity = world.registry:createEntity()
		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)
		CollectionService:AddTag(instance, SHARED_INSTANCE_TAG_NAME)
	end

	return entity
end

local function getAttributeMap(instance, definition)
	local defaultSuccess, default = definition.type:tryDefault()

	if not defaultSuccess then
		return false, default
	end

	local attributeSuccess, attributeMap = Dom.tryToAttributes(instance, 0, definition, default)

	return attributeSuccess, attributeMap, default
end

function Anatta.addComponent(world, instance, definition)
	local entity = getValidEntity(world, instance)
	local success, attributeMap, defaultValue = getAttributeMap(instance, definition)

	if not success then
		return false, attributeMap
	end

	attributeMap[ENTITY_ATTRIBUTE_NAME] = entity

	for attributeName, attributeValue in pairs(attributeMap) do
		if typeof(attributeValue) == "Instance" then
			instance.__anattaRefs[attributeName].Value = attributeValue
			instance:SetAttribute(attributeName, attributeValue.Name)
		else
			instance:SetAttribute(attributeName, attributeValue)
		end
	end

	CollectionService:AddTag(instance, definition.name)
	world.registry:addComponent(entity, definition, defaultValue)

	return true
end

function Anatta.removeComponent(world, instance, definition)
	local entity = getValidEntity(world, instance)
	local success, attributeMap = getAttributeMap(instance, definition)

	if not success then
		return false, attributeMap
	end

	world.registry:tryRemoveComponent(entity, definition)

	for attributeName, attributeValue in pairs(attributeMap) do
		if typeof(attributeValue) == "Instance" then
			local anattaRefs = instance:FindFirstChild("__anattaRefs")

			if anattaRefs then
				local objectValue = anattaRefs:FindFirstChild(attributeName)

				if objectValue then
					objectValue:Destroy()
				end

				if not next(anattaRefs:GetChildren()) then
					anattaRefs:Destroy()
				end
			end
		end

		if attributeName ~= ENTITY_ATTRIBUTE_NAME then
			instance:SetAttribute(attributeName, nil)
		end
	end

	if world.registry:entityIsOrphaned(entity) then
		CollectionService:RemoveTag(instance, SHARED_INSTANCE_TAG_NAME)
		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)
	end

	CollectionService:RemoveTag(instance, definition.name)

	return true
end

return Anatta

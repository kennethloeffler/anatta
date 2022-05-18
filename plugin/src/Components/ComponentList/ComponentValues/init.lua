local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Modules = script.Parent.Parent.Parent.Parent
local Properties = script.Parent.Parent.Properties
local Roact = require(Modules.Roact)
local Anatta = require(Modules.Anatta)
local ComponentManager = require(script.Parent.Parent.Parent.ComponentManager)
local ComponentAnnotation = require(script.Parent.Parent.Parent.ComponentManager.ComponentAnnotation)

local Boolean = require(Properties.Boolean)
local EnumItem = require(Properties.EnumItem)
local InlineButton = require(Properties.InlineButton)
local InstanceSelect = require(Properties.InstanceSelect)
local NumberInput = require(Properties.NumberInput)
local StringInput = require(Properties.StringInput)
local UDim2Input = require(Properties.UDim2Input)
local UDimInput = require(Properties.UDimInput)
local Vector2Input = require(Properties.Vector2Input)
local Vector3Input = require(Properties.Vector3Input)

local VerticalExpandingList = require(Modules.StudioComponents.VerticalExpandingList)
local CollapsibleSection = require(script.CollapsibleSection)

local ENTITY_ATTRIBUTE_NAME = Anatta.Constants.EntityAttributeName
local INSTANCE_REF_FOLDER = Anatta.Constants.InstanceRefFolder

local ComponentValues = Roact.Component:extend("ComponentValues")

local function createInstanceElement(name, attributeName, typeDefinition, value, values)
	local typeParam = typeDefinition.typeParams[1]

	local currentInstance = if value and value.Parent and value.Parent ~= workspace.Terrain then value else nil

	return Roact.createElement(InstanceSelect, {
		Key = name,
		Instance = currentInstance,
		IsA = typeDefinition.typeName == "instanceIsA" and typeParam,
		ClassName = typeDefinition.typeName == "instanceOf" and typeParam,

		OnChanged = function(instance)
			ChangeHistoryService:SetWaypoint(("Changing ref %s"):format(attributeName))

			for linkedInstance in pairs(values) do
				linkedInstance[INSTANCE_REF_FOLDER][attributeName].Value = instance
			end

			ChangeHistoryService:SetWaypoint(("Changed ref %s"):format(attributeName))
		end,
	})
end

local function makeInputElement(elementKind)
	return function(name, attributeName, _, value, linkedInstances)
		return Roact.createElement(elementKind, {
			Key = name,
			Value = value,
			OnChanged = function(newValue)
				if newValue == nil then
					return
				end

				ChangeHistoryService:SetWaypoint(("Changing attribute %s"):format(attributeName))

				for linkedInstance in pairs(linkedInstances) do
					linkedInstance:SetAttribute(attributeName, newValue)
				end

				ChangeHistoryService:SetWaypoint(("Changed attribute %s"):format(attributeName))
			end,
		})
	end
end

local function createArrayAddElement(attributeName, typeDefinition, value, linkedInstances, indentCount)
	return Roact.createElement(InlineButton, {
		Key = attributeName,
		Text = "+ Add Item",
		Indents = indentCount,
		OnActivated = function()
			local newIndex = #value + 1

			local newValueSuccess, newValue = typeDefinition.typeParams[1]:tryDefault()

			if not newValueSuccess then
				return warn(newValue)
			end

			value[newIndex] = newValue

			local definition = { name = attributeName, type = typeDefinition }

			for linkedInstance in pairs(linkedInstances) do
				ComponentAnnotation.apply(linkedInstance, definition, value)
			end

			ComponentManager._global:_updateStore()
		end,
	})
end

local Types = {
	instance = createInstanceElement,
	Instance = createInstanceElement,
	instanceIsA = createInstanceElement,
	instanceOf = createInstanceElement,
	number = makeInputElement(NumberInput),
	boolean = makeInputElement(Boolean),
	string = makeInputElement(StringInput),
	UDim2 = makeInputElement(UDim2Input),
	UDim = makeInputElement(UDimInput),
	Vector2 = makeInputElement(Vector2Input),
	Vector3 = makeInputElement(Vector3Input),

	literal = function(name, attributeName, typeDefinition, value, values)
		local enums = {}
		local mockEnum = {
			GetEnumItems = function()
				return enums
			end,
		}

		for _, item in ipairs(typeDefinition.typeParams) do
			local itemName = item.typeParams[1]

			mockEnum[itemName] = itemName
			table.insert(enums, { Name = itemName })
		end

		return Roact.createElement(EnumItem, {
			Key = name,
			Enum = mockEnum,
			Selected = {
				Name = value,
			},
			OnSelected = function(enumItemName)
				ChangeHistoryService:SetWaypoint(("Changing attribute %s"):format(attributeName))

				for linkedInstance in pairs(values) do
					linkedInstance:SetAttribute(attributeName, enumItemName)
				end

				ChangeHistoryService:SetWaypoint(("Changed attribute %s"):format(attributeName))
			end,
		})
	end,

	entity = function(name, attributeName, _, _, values)
		return Roact.createElement(InstanceSelect, {
			Key = name,
			OnChanged = function(instance)
				ChangeHistoryService:SetWaypoint(("Changing attribute %s"):format(attributeName))

				for linkedInstance in pairs(values) do
					local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

					if entity then
						linkedInstance:SetAttribute(attributeName, entity)
					else
						warn(("%s does not have a linked entity"):format(instance:GetFullName()))
					end
				end

				ChangeHistoryService:SetWaypoint(("Changed attribute %s"):format(attributeName))
			end,
		})
	end,
}

local function createComponentMembers(
	name,
	attributeName,
	typeDefinition,
	value,
	linkedInstances,
	members,
	recursedCount
)
	members = members or {}

	local typeOk, concreteType = typeDefinition:tryGetConcreteType()

	if not typeOk then
		warn(concreteType)
		return members
	end

	if typeof(concreteType) == "table" then
		local typeParams

		if typeDefinition.typeName == "strictArray" then
			typeParams = typeDefinition.typeParams
		else
			typeParams = typeDefinition.typeParams[1]
		end

		if recursedCount then
			local subMembers = {}

			if typeDefinition.typeName == "array" then
				for arrayIndex, fieldValue in ipairs(value) do
					local fieldAttributeName = ("%s_%s"):format(attributeName, arrayIndex)
					local fieldTypeDefinition = typeParams

					createComponentMembers(
						("%s%s"):format(string.rep("  ", recursedCount), tostring(arrayIndex)),
						fieldAttributeName,
						fieldTypeDefinition,
						fieldValue,
						linkedInstances,
						subMembers,
						recursedCount + 1
					)
				end

				table.insert(subMembers, createArrayAddElement(attributeName, typeDefinition, value, linkedInstances))
			else
				for fieldName in pairs(concreteType) do
					local fieldAttributeName = ("%s_%s"):format(attributeName, fieldName)
					local fieldTypeDefinition = typeParams[fieldName]
					local fieldValue = value[fieldName]

					createComponentMembers(
						("%s%s"):format(string.rep("  ", recursedCount), fieldName),
						fieldAttributeName,
						fieldTypeDefinition,
						fieldValue,
						linkedInstances,
						subMembers,
						recursedCount + 1
					)
				end
			end

			table.sort(subMembers, function(lhs, rhs)
				return lhs.props.Key < rhs.props.Key
			end)

			table.insert(
				members,
				Roact.createElement(CollapsibleSection, {
					Key = ("%s%s"):format(string.rep("  ", recursedCount), name),
					HeaderText = ("%s%s"):format(string.rep("  ", recursedCount), name),
					OnToggled = function() end,
				}, subMembers)
			)
		else
			if typeDefinition.typeName == "array" then
				for arrayIndex, fieldValue in ipairs(value) do
					local fieldAttributeName = ("%s_%s"):format(attributeName, arrayIndex)
					local fieldTypeDefinition = typeParams

					createComponentMembers(
						arrayIndex,
						fieldAttributeName,
						fieldTypeDefinition,
						fieldValue,
						linkedInstances,
						members,
						1
					)
				end

				table.insert(members, createArrayAddElement(attributeName, typeDefinition, value, linkedInstances))
			else
				for fieldName in pairs(concreteType) do
					local fieldAttributeName = ("%s_%s"):format(attributeName, fieldName)
					local fieldTypeDefinition = typeParams[fieldName]
					local fieldValue = value[fieldName]

					createComponentMembers(
						fieldName,
						fieldAttributeName,
						fieldTypeDefinition,
						fieldValue,
						linkedInstances,
						members,
						1
					)
				end
			end
		end
	elseif Types[concreteType] ~= nil then
		local element = Types[concreteType](name, attributeName, typeDefinition, value, linkedInstances)
		table.insert(members, element)
	end

	return members
end

function ComponentValues:render()
	local props = self.props
	local definition = props.Definition
	local name = definition.name
	local typeDefinition = definition.pluginType and definition.pluginType or definition.type
	local _, value = next(props.Values)

	-- TODO: compare all values to display ambiguous fields
	local members = createComponentMembers(name, name, typeDefinition, value, props.Values)

	table.sort(members, function(lhs, rhs)
		return tostring(lhs.props.Key) < tostring(rhs.props.Key)
	end)

	return Roact.createElement(VerticalExpandingList, {}, members)
end

return ComponentValues

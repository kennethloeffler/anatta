local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local Anatta = require(Modules.Anatta)

local ComponentManager = require(script.Parent.Parent.Parent.ComponentManager)
local ComponentAnnotation = require(script.Parent.Parent.Parent.ComponentManager.ComponentAnnotation)

local Properties = script.Parent.Parent.Properties
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

local function createInstanceElement(name, attributeName, typeDefinition, value, linkedInstances, layoutOrder)
	local typeParam = typeDefinition.typeParams[1]

	local currentInstance = if value and value.Parent and value.Parent ~= workspace.Terrain then value else nil

	return Roact.createElement(InstanceSelect, {
		Key = name,
		Instance = currentInstance,
		IsA = typeDefinition.typeName == "instanceIsA" and typeParam,
		ClassName = typeDefinition.typeName == "instanceOf" and typeParam,
		LayoutOrder = layoutOrder,

		OnChanged = function(instance)
			ChangeHistoryService:SetWaypoint(("Changing ref %s"):format(attributeName))

			for linkedInstance in pairs(linkedInstances) do
				linkedInstance[INSTANCE_REF_FOLDER][attributeName].Value = instance
			end

			ChangeHistoryService:SetWaypoint(("Changed ref %s"):format(attributeName))
		end,
	})
end

local function makeInputElement(elementKind)
	return function(name, attributeName, _, value, linkedInstances, layoutOrder)
		return Roact.createElement(elementKind, {
			Key = name,
			Value = value,
			LayoutOrder = layoutOrder,
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

local function createArrayAddElement(attributeName, typeDefinition, value, linkedInstances, layoutOrder)
	return Roact.createElement(InlineButton, {
		Key = attributeName,
		Text = "+ Add Item",
		LayoutOrder = layoutOrder,
		OnActivated = function()
			local newIndex = #value + 1

			local newValueSuccess, newValue = typeDefinition.typeParams[1]:tryDefault()

			if not newValueSuccess then
				return warn(newValue)
			end

			value[newIndex] = newValue

			local definition = { name = attributeName, type = typeDefinition }

			ChangeHistoryService:SetWaypoint(("Adding array element %s%s"):format(attributeName, newIndex))

			for linkedInstance in pairs(linkedInstances) do
				ComponentAnnotation.apply(linkedInstance, definition, value)
			end

			ChangeHistoryService:SetWaypoint(("Added array element %s%s"):format(attributeName, newIndex))

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

	literal = function(name, attributeName, typeDefinition, value, linkedInstances, layoutOrder)
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
			LayoutOrder = layoutOrder,
			OnSelected = function(enumItemName)
				ChangeHistoryService:SetWaypoint(("Changing attribute %s"):format(attributeName))

				for linkedInstance in pairs(linkedInstances) do
					linkedInstance:SetAttribute(attributeName, enumItemName)
				end

				ChangeHistoryService:SetWaypoint(("Changed attribute %s"):format(attributeName))
			end,
		})
	end,

	entity = function(name, attributeName, _, _, linkedInstances, layoutOrder)
		return Roact.createElement(InstanceSelect, {
			Key = name,
			LayoutOrder = layoutOrder,
			OnChanged = function(instance)
				ChangeHistoryService:SetWaypoint(("Changing attribute %s"):format(attributeName))

				for linkedInstance in pairs(linkedInstances) do
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

local function createComponentMembers(componentDefinition, linkedInstances)
	local function createMembers(depth, members, name, attributeName, typeDefinition, value)
		local typeOk, concreteType = typeDefinition:tryGetConcreteType()

		if not typeOk then
			warn(concreteType)
			return members
		end

		if typeof(concreteType) == "table" then
			local subMembers = if depth > 0 then {} else members

			if typeDefinition.typeName == "array" then
				local typeParam = typeDefinition.typeParams[1]

				for arrayIndex, fieldValue in ipairs(value) do
					local fieldAttributeName = ("%s_%s"):format(attributeName, arrayIndex)

					createMembers(
						depth + 1,
						subMembers,
						("%s%s"):format(string.rep("  ", depth), tostring(arrayIndex)),
						fieldAttributeName,
						typeParam,
						fieldValue
					)
				end

				local element = createArrayAddElement(attributeName, typeDefinition, value, linkedInstances)

				subMembers[attributeName] = element
			else
				local typeParams = if typeDefinition.typeName == "strictInterface"
					then typeDefinition.typeParams[1]
					else typeDefinition.typeParams

				for fieldName in pairs(concreteType) do
					local fieldAttributeName = ("%s_%s"):format(attributeName, fieldName)
					local fieldTypeDefinition = typeParams[fieldName]
					local fieldValue = value[fieldName]

					createMembers(
						depth + 1,
						subMembers,
						("%s%s"):format(string.rep("  ", depth), fieldName),
						fieldAttributeName,
						fieldTypeDefinition,
						fieldValue
					)
				end
			end

			if depth > 0 then
				local element = Roact.createElement(CollapsibleSection, {
					Key = ("%s%s"):format(string.rep("  ", depth), name),
					HeaderText = ("%s%s"):format(string.rep("  ", depth), name),
					OnToggled = function() end,
					SortOrder = Enum.SortOrder.Name,
				}, subMembers)

				members["_" .. attributeName] = element
			end
		elseif Types[concreteType] ~= nil then
			local element = Types[concreteType](name, attributeName, typeDefinition, value, linkedInstances)

			members[attributeName] = element
		end
	end

	local componentMembers = {}
	local _, componentValue = next(linkedInstances)
	local componentName = componentDefinition.name
	local componentTypeDefinition = componentDefinition.pluginType and componentDefinition.pluginType
		or componentDefinition.type

	createMembers(0, componentMembers, componentName, componentName, componentTypeDefinition, componentValue)

	return componentMembers
end

function ComponentValues:render()
	return Roact.createElement(
		VerticalExpandingList,
		{ LayoutOrder = self.props.LayoutOrder, SortOrder = Enum.SortOrder.Name },
		createComponentMembers(self.props.Definition, self.props.ValuesFromInstance)
	)
end

return ComponentValues

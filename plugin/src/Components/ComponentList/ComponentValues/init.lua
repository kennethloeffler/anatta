local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Modules = script.Parent.Parent.Parent.Parent
local Properties = script.Parent.Parent.Properties
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local Actions = require(Modules.Plugin.Actions)
local Anatta = require(Modules.Anatta)
local PluginGlobals = require(Modules.Plugin.PluginGlobals)

local Boolean = require(Properties.Boolean)
local EnumItem = require(Properties.EnumItem)
local InstanceSelect = require(Properties.InstanceSelect)
local NumberInput = require(Properties.NumberInput)
local StringInput = require(Properties.StringInput)
local UDim2Input = require(Properties.UDim2Input)
local UDimInput = require(Properties.UDimInput)
local Vector2Input = require(Properties.Vector2Input)
local Vector3Input = require(Properties.Vector3Input)

local VerticalExpandingList = require(Modules.StudioComponents.VerticalExpandingList)

local ENTITY_ATTRIBUTE_NAME = Anatta.Constants.EntityAttributeName
local INSTANCE_REF_FOLDER = Anatta.Constants.InstanceRefFolder

local ComponentValues = Roact.Component:extend("ComponentValues")

local function createInstanceElement(name, attributeName, typeDefinition, value, values)
	local typeParam = typeDefinition.typeParams[1]

	local currentInstance = if value and value.Parent then value else nil

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
	return function(name, attributeName, _, value, values)
		return Roact.createElement(elementKind, {
			Key = name,
			Value = value,
			OnChanged = function(newValue)
				ChangeHistoryService:SetWaypoint(("Changing attribute %s"):format(attributeName))

				for linkedInstance in pairs(values) do
					linkedInstance:SetAttribute(attributeName, newValue)
				end

				ChangeHistoryService:SetWaypoint(("Changed attribute %s"):format(attributeName))
			end,
		})
	end
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

local function createComponentMembers(name, attributeName, typeDefinition, value, values, members, attributeMap)
	members = members or {}
	attributeMap = attributeMap or {}

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

		for fieldName in pairs(concreteType) do
			local fieldAttributeName = ("%s_%s"):format(attributeName, fieldName)
			local fieldTypeDefinition = typeParams[fieldName]
			local fieldValue = value[fieldName]

			createComponentMembers(
				fieldName,
				fieldAttributeName,
				fieldTypeDefinition,
				fieldValue,
				values,
				members,
				attributeMap
			)
		end
	elseif Types[concreteType] ~= nil then
		local element = Types[concreteType](name, attributeName, typeDefinition, value, values)
		table.insert(members, element)
	end

	return members
end

function ComponentValues:render()
	local props = self.props
	local componentDefinition = props.Definition
	local name = componentDefinition.name
	local typeDefinition = componentDefinition.pluginType and componentDefinition.pluginType or componentDefinition.type
	local _, value = next(props.Values)
	-- TODO: compare all values to display ambiguous fields

	local members = createComponentMembers(name, name, typeDefinition, value, props.Values)

	table.sort(members, function(lhs, rhs)
		return lhs.props.Key < rhs.props.Key
	end)

	return Roact.createElement(VerticalExpandingList, {}, members)
end

local function mapStateToProps(state)
	local icon
	local drawType
	local color
	local alwaysOnTop = false
	for _, v in pairs(state.ComponentData) do
		if v.Name == state.ComponentMenu then
			icon = v.Icon
			drawType = v.DrawType or "Box"
			color = v.Color
			alwaysOnTop = v.AlwaysOnTop
		end
	end

	return {
		componentMenu = state.ComponentMenu,
		componentIcon = icon or "component_green",
		componentColor = color,
		componentDrawType = drawType,
		componentAlwaysOnTop = alwaysOnTop,
	}
end

local function mapDispatchToProps(dispatch)
	return {
		close = function()
			dispatch(Actions.OpenComponentMenu(nil))
		end,
		iconPicker = function(componentMenu)
			dispatch(Actions.ToggleIconPicker(componentMenu))
		end,
		colorPicker = function(componentMenu)
			PluginGlobals.promptPickColor(dispatch, componentMenu)
		end,
		groupPicker = function(componentMenu)
			dispatch(Actions.ToggleGroupPicker(componentMenu))
		end,
		instanceView = function(componentMenu)
			dispatch(Actions.OpenInstanceView(componentMenu))
		end,
	}
end

ComponentValues = RoactRodux.connect(mapStateToProps, mapDispatchToProps)(ComponentValues)

return ComponentValues

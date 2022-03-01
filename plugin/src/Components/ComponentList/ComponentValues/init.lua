local Modules = script.Parent.Parent.Parent.Parent
local Properties = script.Parent.Parent.Properties
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local Llama = require(Modules.Llama)
local Actions = require(Modules.Plugin.Actions)
local Anatta = require(Modules.Anatta)
local PluginGlobals = require(Modules.Plugin.PluginGlobals)

local InstanceSelect = require(Properties.InstanceSelect)
local NumberInput = require(Properties.NumberInput)
local VerticalExpandingList = require(Modules.StudioComponents.VerticalExpandingList)

local ComponentValues = Roact.Component:extend("ComponentValues")

local function createInstanceElement(name, typeDefinition, value)
	local typeParam = typeDefinition.typeParams[1]

	return Roact.createElement(InstanceSelect, {
		Key = name,
		Instance = value,
		IsA = typeDefinition.typeName == "instanceIsA" and typeParam,
		ClassName = typeDefinition.typeName == "instanceOf" and typeParam,

		OnChanged = function() end,
	})
end

local Types = {
	instance = createInstanceElement,
	Instance = createInstanceElement,
	instanceIsA = createInstanceElement,
	instanceOf = createInstanceElement,
	number = function(name, typeDefinition, value)
		return Roact.createElement(NumberInput, { Key = name, Value = value, OnChanged = function() end })
	end,
}

local function createComponentMembers(name, typeDefinition, value, members)
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
			createComponentMembers(fieldName, typeParams[fieldName], value[fieldName], members)
		end
	elseif Types[concreteType] ~= nil then
		local element = Types[concreteType](name, typeDefinition, value)
		table.insert(members, element)
	end

	return members
end

function ComponentValues:render()
	local props = self.props
	local componentDefinition = props.Definition
	local name = componentDefinition.name
	local typeDefinition = componentDefinition.pluginType and componentDefinition.pluginType or componentDefinition.type

	return Roact.createElement(
		VerticalExpandingList,
		{},
		createComponentMembers(name, typeDefinition, props.Values[1], {})
	)
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

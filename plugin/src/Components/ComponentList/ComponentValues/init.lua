local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local Actions = require(Modules.Plugin.Actions)
local ComponentManager = require(Modules.Plugin.ComponentManager)
local PluginGlobals = require(Modules.Plugin.PluginGlobals)

local VerticalExpandingList = require(Modules.StudioComponents.VerticalExpandingList)

local ComponentValues = Roact.Component:extend("ComponentValues")

local function createComponentMembers(type)
	if typeof(type) == "table" then
		for _, v in pairs(type) do
			createComponentMembers(v)
		end
	elseif typeof(type) == "number" then
	end
end

function ComponentValues:render()
	local props = self.props
	local typeOk, type = props.componentMenu.Definition.type:tryGetConcreteType()

	if not typeOk then
		warn(type)
	end

	return Roact.createElement(VerticalExpandingList, {}, createComponentMembers(type))
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

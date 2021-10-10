local Modules = script.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local Actions = require(Modules.Plugin.Actions)
local Util = require(Modules.Plugin.Util)

local InstanceList = require(script.InstanceList)
local ComponentizedInstanceProvider = require(script.ComponentizedInstanceProvider)

local function InstanceView(props)
	return Roact.createElement(ComponentizedInstanceProvider, {
		componentName = props.componentName,
	}, {
		render = function(parts, selected)
			return Roact.createElement(InstanceList, {
				parts = parts,
				selected = selected,
				componentName = props.componentName,
				componentIcon = props.componentIcon,
				close = props.close,
			})
		end,
	})
end

local function mapStateToProps(state)
	local component = state.InstanceView
		and Util.findIf(state.ComponentData, function(item)
			return item.Name == state.InstanceView
		end)

	return {
		componentName = state.InstanceView,
		componentIcon = component and component.Icon or nil,
	}
end

local function mapDispatchToProps(dispatch)
	return {
		close = function()
			dispatch(Actions.OpenInstanceView(nil))
		end,
	}
end

InstanceView = RoactRodux.connect(mapStateToProps, mapDispatchToProps)(InstanceView)

return InstanceView

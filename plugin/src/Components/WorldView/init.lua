local Modules = script.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)

local WorldVisual = require(script.WorldVisual)
local WorldProvider = require(script.WorldProvider)

local function WorldView(props)
	if props.enabled then
		return Roact.createElement(WorldProvider, {}, {
			render = function(partsList)
				return Roact.createElement(WorldVisual, {
					partsList = partsList,
					components = props.components,
				})
			end,
		})
	else
		return nil
	end
end

local function mapStateToProps(state)
	return {
		enabled = state.WorldView,
		components = state.ComponentData,
	}
end

WorldView = RoactRodux.connect(mapStateToProps)(WorldView)

return WorldView

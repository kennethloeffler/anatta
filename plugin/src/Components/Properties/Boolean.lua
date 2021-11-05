local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local StudioComponents = require(Modules.StudioComponents)

local BaseProperty = require(script.Parent.BaseProperty)

local function Boolean(props)
	return Roact.createElement(BaseProperty, {
		Text = props.Key
	}, {
		Centered = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 15),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 5, 0.5, 0),
		}, {
			Checkbox = Roact.createElement(StudioComponents.Checkbox, {
				Value = props.Value,
				OnActivated = props.OnActivated
			})
		})
	})
end

return Boolean
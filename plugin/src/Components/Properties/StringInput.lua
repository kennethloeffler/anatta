local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local StudioComponents = require(Modules.StudioComponents)

local BaseProperty = require(script.Parent.BaseProperty)

local function StringInput(props)
	return Roact.createElement(BaseProperty, {
		Text = props.Key,
		LayoutOrder = props.LayoutOrder,
	}, {
		Container = Roact.createElement("Frame", {
			[Roact.Ref] = props._FieldRef,
			Size = UDim2.new(1, 0, 0, 21),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
		}, {
			StringInput = Roact.createElement(StudioComponents.TextInput, {
				BorderSizePixel = 0,
				OnFocused = props.OnFocused,
				OnFocusLost = props.OnChanged,
				OnChanged = function() end,
				Text = props.Value,
				ClearTextOnFocus = false,
			}),
		}),
	})
end

return StringInput

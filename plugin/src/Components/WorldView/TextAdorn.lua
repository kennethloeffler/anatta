local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local Constants = require(Modules.Plugin.Constants)

local function TextAdorn(props)
	local children = {}
	if #props.ComponentName > 1 then
		children.UIListLayout = Roact.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	end
	for i = 1, #props.ComponentName do
		local name = props.ComponentName[i]
		children[name] = Roact.createElement("TextLabel", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 1 / #props.ComponentName, 0),
			Text = name,
			TextScaled = true,
			TextSize = 20,
			Font = Enum.Font.SourceSansBold,
			TextColor3 = Constants.White,
			BackgroundTransparency = 1.0,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			TextStrokeTransparency = 0.0,
		})
	end
	return Roact.createElement("BillboardGui", {
		Adornee = props.Adornee,
		Size = UDim2.new(10, 0, #props.ComponentName, 0),
		SizeOffset = Vector2.new(0.5, 0.5),
		ExtentsOffsetWorldSpace = Vector3.new(1, 1, 1),
		AlwaysOnTop = props.AlwaysOnTop,
	}, children)
end

return TextAdorn

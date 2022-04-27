local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local StudioComponents = require(Modules.StudioComponents)

local function BaseProperty(props)
	props.Indents = props.Indents or 1

	return StudioComponents.withTheme(function(theme)
		return Roact.createElement("Frame", {
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderSizePixel = 1,
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			Size = UDim2.new(1, 0, 0, 25),
			ZIndex = props.ZIndex,
		}, {
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 25 * props.Indents),
			}),
			Button = Roact.createElement(StudioComponents.Button, {
				Size = UDim2.new(1, 0, 1, 0),
				Text = "  " .. props.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				BorderSizePixel = 0,
				TextTruncate = Enum.TextTruncate.AtEnd,
				OnActivated = function()
					if props.OnActivated then
						props.OnActivated()
					end
				end,
				LayoutOrder = 0,
			}),
		})
	end)
end

return BaseProperty

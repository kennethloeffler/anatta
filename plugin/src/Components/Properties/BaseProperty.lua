local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local withTheme = require(Modules.StudioComponents).withTheme

local function BaseProperty(props)
	return withTheme(function(theme)
		return Roact.createElement("Frame", {
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderSizePixel = 1,
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			Size = UDim2.new(1, 0, 0, 25),
		}, {
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 25)
			}),
			Key = Roact.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0.5, 0, 1, 0),
				Text = props.Text,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			ValueContainer = Roact.createElement("Frame", {
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				BorderSizePixel = 1,
				BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
				Size = UDim2.new(0.5, 0, 1, 0),
				Position = UDim2.new(0.5, 0, 0, 0)
			}, {
				Value = Roact.oneChild(props[Roact.Children])
			})
		})
	end)
end

return BaseProperty
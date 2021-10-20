local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)
local StudioComponents = require(Vendor.StudioComponents)

local EnumItem = require(script.Parent.EnumItem)

local Wrapper = Roact.Component:extend("CheckboxWrapper")

function Wrapper:init()
	self:setState({
		Selected = Enum.Font.Cartoon,
	})
end

function Wrapper:render()
	return StudioComponents.withTheme(function(theme)
		return Roact.createFragment({
			Layout = Roact.createElement("UIListLayout", {
				Padding = UDim.new(0, 5),
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.Name,
			}),
			Container = Roact.createElement("Frame", {
				LayoutOrder = 0,
				Size = UDim2.fromOffset(300, 25),
				BackgroundTransparency = 1,
			}, {
				EnumItem = Roact.createElement(EnumItem, {
					Key = "Font",
					Enum = Enum.Font,
					Selected = self.state.Selected,
					OnSelected = function(enumItem)
						self:setState({
							Selected = enumItem
						})
					end,
				})
			}),
			Display = Roact.createElement("TextLabel", {
				Size = UDim2.fromOffset(300, 25),
				BackgroundTransparency = 1,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
				Text = "Hello world! Everyone is epic :D",
				Font = self.state.Selected,
				TextScaled = true,
			})
		})
	end)
end

return function(target)
	local element = Roact.createElement(Wrapper)
	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end

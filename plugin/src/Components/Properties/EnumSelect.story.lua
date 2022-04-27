local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local EnumSelect = require(script.Parent.EnumSelect)

local Wrapper = Roact.Component:extend("CheckboxWrapper")

function Wrapper:init()
	self:setState({
		Selected = Enum.Font,
	})
end

function Wrapper:render()
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
			EnumSelect = Roact.createElement(EnumSelect, {
				Key = "Pick Yo Enum",
				Selected = self.state.Selected,
				OnSelected = function(enum)
					self:setState({
						Selected = enum,
					})
				end,
			}),
		}),
	})
end

return function(target)
	local element = Roact.createElement(Wrapper)
	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end

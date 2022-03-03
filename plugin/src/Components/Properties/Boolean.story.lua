local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local Boolean = require(script.Parent.Boolean)

local Wrapper = Roact.Component:extend("CheckboxWrapper")

function Wrapper:init()
	self:setState({
		Value = true,
	})
end

function Wrapper:render()
	local value = self.state.Value
	
	return Roact.createFragment({
		Layout = Roact.createElement("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Container = Roact.createElement("Frame", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			Boolean = Roact.createElement(Boolean, {
				Key = "Hello World",
				Value = value,
				OnActivated = function()
					self:setState({ Value = not value })
				end,
			})
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

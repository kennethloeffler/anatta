local Modules = script.Parent.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local VerticalCollapsibleSection = require(Modules.StudioComponents.VerticalCollapsibleSection)

local CollapsibleSection = Roact.Component:extend("CollapsibleSection")

function CollapsibleSection:render()
	return Roact.createElement(VerticalCollapsibleSection, {
		OnToggled = function()
			self:setState({
				Collapsed = not self.state.Collapsed,
			})
		end,

		Collapsed = self.state.Collapsed,
		HeaderText = self.props.HeaderText,
		Key = self.props.Key,
		LayoutOrder = self.props.LayoutOrder,
		SortOrder = self.props.SortOrder,
	}, self.props[Roact.Children])
end

return CollapsibleSection

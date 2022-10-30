local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local StringInput = require(script.Parent.StringInput)

local ComplexStringInput = Roact.Component:extend("ComplexStringInput")

--[[
	OnChanged = () => string
]]
function ComplexStringInput:init()
	self.fieldRef = Roact.createRef()
	self.lastGoodInput = self.props.Value

	self:setState({
		Value = self.props.Value,
	})
end

function ComplexStringInput:getFieldFromRef()
	return self.fieldRef:getValue().StringInput
end

function ComplexStringInput:validateField()
	local field = self:getFieldFromRef()

	local validated, overwrite = self.props.Validate(field.Text)

	if validated then
		if overwrite then
			field.Text = overwrite
		end

		self.lastGoodInput = field.Text
	else
		field.Text = self.lastGoodInput
	end
end

function ComplexStringInput:filterField()
	local field = self:getFieldFromRef()

	field.Text = self.props.Filter(field.Text)
end

function ComplexStringInput:render()
	return Roact.createElement(StringInput, {
		_FieldRef = self.fieldRef,
		Value = self.props.Value,
		Key = self.props.Key,
		LayoutOrder = self.props.LayoutOrder,

		OnChanged = function()
			if self.props.Filter then
				self:filterField()
				self.props.OnChanged(self.props.Parse(self:getFieldFromRef().Text))
			end
		end,
	})
end

return ComplexStringInput

local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local StudioComponents = require(Modules.StudioComponents)

local BaseProperty = require(script.Parent.BaseProperty)

local InstanceSelect = Roact.Component:extend("InstanceSelect")

--[[
	OnChanged = () => string
]]
function InstanceSelect:init()
	self.fieldRef = Roact.createRef()
	self.lastGoodInput = self.props.Value

	self:setState({
		Instance = self.props.Instance,
		Selecting = false,
	})
end

function InstanceSelect:render()
	return Roact.createElement(BaseProperty, {
		Text = self.props.Key
	}, {
		InstanceSelector = Roact.createElement(StudioComponents.Button, {
			Size = UDim2.new(1, 0, 1, 0),
			Text = self.state.Instance.Name,
			OnActivated = function()
				if self.state.Selecting then
					return
				end

				self:setState({
					Selecting = true,
				})

				local oldSelection = Selection:Get()

				Selection:Set({})

				Selection.SelectionChanged:Wait()

				local newSelected = Selection:Get()[1]

				if newSelected then
					self:setState({
						Instance = newSelected
					})
					self.props.OnChanged(newSelected)
				end

				RunService.Heartbeat:Wait()

				Selection:Set(oldSelection)

				self:setState({
					Selecting = false,
				})
			end,
			LayoutOrder = 0,
			Selected = self.state.Selecting,
		})
	})
end

return InstanceSelect

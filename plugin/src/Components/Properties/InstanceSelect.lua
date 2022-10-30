local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local StudioComponents = require(Modules.StudioComponents)

local ComponentManager = require(script.Parent.Parent.Parent.ComponentManager)

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
	local requiredKind = self.props.ClassName or self.props.IsA
	local instance = self.props.Instance

	return Roact.createElement(BaseProperty, {
		Text = ("%s (%s)"):format(self.props.Key, requiredKind or "any"),
	}, {
		InstanceSelector = Roact.createElement(StudioComponents.Button, {
			Size = UDim2.new(1, 0, 1, 0),
			Text = instance and instance:GetFullName() or "<none>",
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
			TextTruncate = Enum.TextTruncate.AtEnd,
			OnActivated = function()
				if self.state.Selecting then
					return
				end

				self:setState({
					Selecting = true,
				})

				local oldSelection = Selection:Get()

				ComponentManager._global:pauseSelection()

				Selection:Set({})
				Selection.SelectionChanged:Wait()

				local newSelected = Selection:Get()[1]

				if newSelected then
					local valid = true
					if self.props.IsA then
						valid = newSelected:IsA(self.props.IsA)
					end

					if self.props.ClassName then
						valid = newSelected.ClassName == self.props.ClassName
					end

					if valid then
						self:setState({
							Instance = newSelected,
						})

						self.props.OnChanged(newSelected)
					end
				end

				RunService.Heartbeat:Wait()

				ComponentManager._global:unpauseSelection()
				Selection:Set(oldSelection)

				self:setState({
					Selecting = false,
				})
			end,
			LayoutOrder = 0,
			Selected = self.state.Selecting,
		}),
	})
end

return InstanceSelect

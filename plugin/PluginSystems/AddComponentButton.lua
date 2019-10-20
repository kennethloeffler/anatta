-- AddComponentButton.lua

-- Copyright 2019 Kenneth Loeffler

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local Selection = game:GetService("Selection")

local Theme = settings().Studio.Theme

local MainText = Enum.StudioStyleGuideColor.MainText
local Button = Enum.StudioStyleGuideColor.Button
local Border = Enum.StudioStyleGuideColor.Border

local Hover = Enum.StudioStyleGuideModifier.Hover
local Selected = Enum.StudioStyleGuideModifier.Selected

local PluginES

local AddComponentWidget = {}

function AddComponentWidget.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginES

	local mainToolbar = pluginWrapper.GetToolbar("WorldSmith")
	local addComponentWidgetButton = pluginWrapper.GetButton(mainToolbar, "Add component...", "Displays/hides a menu which can be used to add components to instances")
	local addComponentWidget = pluginWrapper.GetDockWidget("Add components", Enum.InitialDockState.Float, true, false, 200, 300)
	local scrollingFrame = Instance.new("ScrollingFrame")

	PluginES.AddComponent(scrollingFrame, "VerticalScalingList")

	scrollingFrame.TopImage = ""
	scrollingFrame.BottomImage = ""
	scrollingFrame.ScrollBarImageColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Light)
	scrollingFrame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 16
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, 0)
	scrollingFrame.Parent = addComponentWidget

	addComponentWidgetButton.Click:Connect(function()
		addComponentWidget.Enabled = not addComponentWidget.Enabled
	end)

	PluginES.ComponentAdded("AddComponentButton", function(addComponentButton)
		local componentType = addComponentButton.ComponentType
		local button = Instance.new("TextButton")

		button.Size = UDim2.new(1, 0, 0, 20)
		button.TextColor3 = Theme:GetColor(MainText)
		button.BackgroundColor3 = Theme:GetColor(Button)
		button.AutoButtonColor = false
		button.BorderColor3 = Theme:GetColor(Border)
		button.Name = componentType
		button.Text = componentType
		button.Parent = addComponentButton.Instance

		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				button.BackgroundColor3 = Theme:GetColor(Button, Selected)
				button.BorderColor3 = Theme:GetColor(Border, Selected)
				button.TextColor3 = Theme:GetColor(MainText, Selected)

				PluginES.AddComponent(button, "SerializeAddComponent", {
					EntityList = Selection:Get(),
					ComponentType = componentType
				})
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				button.BackgroundColor3 = Theme:GetColor(Button, Hover)
				button.BorderColor3 = Theme:GetColor(Border, Hover)
				button.TextColor3 = Theme:GetColor(MainText, Hover)
			end
		end)

		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				button.TextColor3 = Theme:GetColor(MainText)
				button.BackgroundColor3 = Theme:GetColor(Button)
				button.BorderColor3 = Theme:GetColor(Border)
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				button.TextColor3 = Theme:GetColor(MainText)
				button.BackgroundColor3 = Theme:GetColor(Button)
				button.BorderColor3 = Theme:GetColor(Border)
			end
		end)
	end)

	PluginES.ComponentKilled("AddComponentButton", function(addComponentButton)
		local button = addComponentButton.Instance[addComponentButton.ComponentType]

		button:Destroy()
	end)

	PluginES.ComponentAdded("ComponentDefinition", function(componentDefinition)
		PluginES.AddComponent(scrollingFrame, "AddComponentButton", {
			ComponentType = componentDefinition.ComponentType
		})
	end)

	PluginES.ComponentKilled("ComponentDefinition", function(componentDefinition)
		for _, addComponentButton in ipairs(PluginES.GetListLypedComponent(scrollingFrame, "AddComponentButton")) do
			if addComponentButton.ComponentType == componentDefinition.ComponentType then
				PluginES.KillComponent(addComponentButton)

				break
			end
		end
	end)

	for _, componentDefinition in ipairs(PluginES.GetAllComponentsOfType("ComponentDefinition")) do
		PluginES.AddComponent(scrollingFrame, "AddComponentButton", {
			ComponentType = componentDefinition.ComponentType
		})
	end
end

return AddComponentWidget

-- ComponentLabels.lua

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

local Theme = settings().Studio.Theme
local GameES
local PluginES

local ArrowClosedImg = ""
local ArrowOpenImg = ""

local Section = Enum.StudioStyleGuideColor.TableItem
local MainText = Enum.StudioStyleGuideColor.MainText

local Hover = Enum.StudioStyleGuideModifier.Hover

local ComponentLabels = {}

local function clearParamFields(label)
	for _, paramField in ipairs(PluginES.GetListTypedComponent(label, "ParamField")) do
		PluginES.KillEntity(paramField.Field)
		PluginES.KillEntity(label.ParamsContainer[paramField.ParamName])
		PluginES.KillComponent(paramField)
	end
end

local function makeParamFields(label, componentLabel, defaults)
	for paramName in pairs(defaults) do
		PluginES.AddComponent(label, "ParamField", {
			ParamName = paramName,
			ComponentLabel = componentLabel
		})
	end
end

function ComponentLabels.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginES
	GameES = pluginWrapper.GameES

	PluginES.ComponentAdded("ComponentLabel", function(componentLabel)
		local componentDesc = GameES.GetComponentDesc()
		local parentFrame = componentLabel.Instance
		local componentId = componentLabel.ComponentId
		local componentType = componentDesc.GetComponentTypeFromId(componentId)
		local label = Instance.new("TextLabel")
		local arrowImg = Instance.new("ImageLabel")
		local paramsContainer = Instance.new("Frame")

		PluginES.AddComponent(paramsContainer, "VerticalScalingList")

		paramsContainer.Size = UDim2.new(1, 0, 0, 0)
		paramsContainer.Position = UDim2.new(0, 0, 0, 32)
		paramsContainer.BackgroundTransparency = 1
		paramsContainer.BorderSizePixel = 0
		paramsContainer.Name = "ParamsContainer"
		paramsContainer.Parent = label

		arrowImg.Image = ArrowClosedImg
		arrowImg.Size = UDim2.new(0, 20, 0, 20)
		arrowImg.BackgroundTransparency = 1
		arrowImg.BorderSizePixel = 0
		arrowImg.AnchorPoint = Vector2.new(0, -0.5)
		arrowImg.Parent = label

		label.Size = UDim2.new(1, 0, 0, 32)
		label.BackgroundColor3 = Theme:GetColor(Section)
		label.TextColor3 = Theme:GetColor(MainText)
		label.Text = ("      %s"):format(componentType)
		label.TextSize = 16
		label.Font = Enum.Font.ArialBold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Name = componentId
		label.LayoutOrder = componentId
		label.Parent = parentFrame

		label.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if not componentLabel.Open then
					componentLabel.Open = true
					arrowImg.Image = ArrowOpenImg
					makeParamFields(label, componentLabel, componentDesc.GetDefaults(componentId))
				else
					clearParamFields(label)
					arrowImg.Image = ArrowClosedImg
					componentLabel.Open = false
				end
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				label.BackgroundColor3 = Theme:GetColor(Section, Hover)
			end
		end)

		label.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				label.BackgroundColor3 = Theme:GetColor(Section)
			end
		end)
	end)

	PluginES.ComponentKilled("ComponentLabel", function(componentLabel)
		local label = componentLabel.Instance[componentLabel.ComponentId]

		if componentLabel.Open then
			clearParamFields(label)
		end

		PluginES.KillEntity(label.ParamsContainer)
		PluginES.KillEntity(label)
	end)
end

return ComponentLabels

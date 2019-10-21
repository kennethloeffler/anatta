-- ParamFields.lua

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

local PluginES
local GameES
local ComponentDesc

local Theme = settings().Studio.Theme

local InputFieldBorder = Enum.StudioStyleGuideColor.InputFieldBorder
local InputFieldBackground = Enum.StudioStyleGuideColor.InputFieldBackground
local MainText = Enum.StudioStyleGuideColor.MainText

local Selected = Enum.StudioStyleGuideModifier.Selected
local Hover = Enum.StudioStyleGuideModifier.Hover

local CheckBoxBackgroundImg = ""
local CheckBoxIndeterminateImg = ""
local CheckBoxTrueImg = ""

local types = {
	Vector2 = Vector2,
	Vector3 = Vector3,
	Vector2int16 = Vector2int16,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2
}


local function splitCommaDelineatedString(str)
	local list = {}

	for s in string.gmatch(str, "([^,]+)") do
		list[#list + 1] = tonumber(s)
	end

	return unpack(list)
end

local function getElementForValueType(ty)
	if ty == "string" or ty == "number" or types[ty] then
		local textBox = Instance.new("TextBox")

		textBox.Size = UDim2.new(1, 0, 1, 0)
		textBox.Position = UDim2.new(0, 5, 0, 0)
		textBox.TextXAlignment = Enum.TextXAlignment.Left
		textBox.TextSize = 16
		textBox.Font = Enum.Font.Arial
		textBox.BackgroundColor3 = Theme:GetColor(InputFieldBackground)
		textBox.BorderColor3 = Theme:GetColor(InputFieldBackground)
		textBox.BorderSizePixel = 0
		textBox.ZIndex = 500
		textBox.BackgroundTransparency = 1
		textBox.TextColor3 = Theme:GetColor(MainText)

		return textBox
	elseif ty == "boolean" then
		local imageButton = Instance.new("ImageButton")
		local imageLabel = Instance.new("ImageLabel")

		imageButton.Size = UDim2.new(0, 24, 0, 24)
		imageButton.BorderSizePixel = 0
		imageButton.Image = CheckBoxBackgroundImg

		imageLabel.Name = "CheckMarkImg"
		imageLabel.Size = UDim2.new(1, 0, 1, 0)
		imageLabel.AnchorPoint = Vector2.new(0, 0.5)
		imageLabel.Position = UDim2.new(0, 24, 0, 0)
		imageLabel.Active = false
		imageLabel.BackgroundTransparency = 1
		imageLabel.BorderSizePixel = 0
		imageLabel.Parent = imageButton

		return imageButton
	else
		error("Unknown type: " .. ty)
	end
end

local ParamFields = {}

function ParamFields.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginES
	GameES = pluginWrapper.GameES

	PluginES.ComponentAdded("ParamField", function(paramField)
		ComponentDesc = GameES.GetComponentDesc()

		local frame = Instance.new("Frame")
		local label = Instance.new("TextLabel")
		local fieldContainer = Instance.new("Frame")
		local componentLabel = paramField.ComponentLabel
		local paramName = paramField.ParamName
		local componentId = componentLabel.ComponentId
		local entityList = componentLabel.EntityList
		local componentType = ComponentDesc.GetComponentTypeFromId(componentId)
		local paramId = ComponentDesc.GetParamIdFromName(componentId, paramName)
		local ty = typeof(ComponentDesc.GetParamDefault(componentId, paramName))
		local valueField = getElementForValueType(ty)
		local cLabel = paramField.Instance
		local value = #entityList == 1 and GameES.GetComponent(entityList[1], componentType)[paramName]

		fieldContainer.Size = UDim2.new(1, 0, 0, 32)
		fieldContainer.Position = UDim2.new(0, 135, 0, 0)
		fieldContainer.BackgroundColor3 = Theme:GetColor(InputFieldBackground)
		fieldContainer.BorderColor3 = Theme:GetColor(InputFieldBorder)
		fieldContainer.ZIndex = 200
		paramField.Field = valueField
		valueField.Parent = fieldContainer
		fieldContainer.Parent = frame

		label.Size = UDim2.new(0, 135, 0, 32)
		label.Text = ("	%s"):format(paramName)
		label.Font = Enum.Font.Arial
		label.TextSize = 16
		label.BorderColor3 = Theme:GetColor(InputFieldBorder)
		label.BackgroundColor3 = Theme:GetColor(InputFieldBackground)
		label.TextColor3 = Theme:GetColor(MainText)
		label.Parent = frame

		frame.Size = UDim2.new(1, 0, 0, 32)
		frame.BackgroundTransparency = 1
		frame.Name = paramName
		frame.LayoutOrder = paramId
		frame.Parent = cLabel.ParamsContainer

		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				fieldContainer.BackgroundColor3 = Theme:GetColor(InputFieldBackground, Hover)
				label.BackgroundColor3 = Theme:GetColor(InputFieldBackground, Hover)
			end
		end)

		frame.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				fieldContainer.BackgroundColor3 = Theme:GetColor(InputFieldBackground)
				label.BackgroundColor3 = Theme:GetColor(InputFieldBackground)
			end
		end)

		if valueField:IsA("TextBox") then
			valueField.Text = value and tostring(value) or ""

			valueField.Focused:Connect(function()
				valueField.BorderColor3 = Theme:GetColor(InputFieldBorder, Selected)
				fieldContainer.BackgroundColor3 = Theme:GetColor(InputFieldBackground, Selected)
				fieldContainer.BorderColor3 = Theme:GetColor(InputFieldBorder, Selected)
				label.BackgroundColor3 = Theme:GetColor(InputFieldBackground, Selected)
			end)

			valueField.FocusLost:Connect(function()
				local val = types[ty] and types[ty].new(splitCommaDelineatedString(valueField.Text))
					or ((ty == "number") and (tonumber(valueField.Text) or value) or valueField.Text)

				valueField.BackgroundColor3 = Theme:GetColor(InputFieldBackground)
				valueField.BorderColor3 = Theme:GetColor(InputFieldBorder)
				fieldContainer.BackgroundColor3 = Theme:GetColor(InputFieldBackground)
				fieldContainer.BorderColor3 = Theme:GetColor(InputFieldBorder)
				label.BackgroundColor3 = Theme:GetColor(InputFieldBackground)

				value = #entityList == 1 and GameES.GetComponent(entityList[1], componentType)[paramName]

				PluginES.AddComponent(cLabel, "SerializeParam", {
					Value = val,
					ParamName = paramName,
					ComponentType = componentType,
					EntityList = entityList
				})

				valueField.Text = tostring(val)
			end)
		elseif valueField:IsA("ImageButton") then
			valueField.Image = value ~= nil and (value and CheckBoxTrueImg or "") or CheckBoxIndeterminateImg

			valueField.MouseButton1Click:Connect(function()
				value = #entityList == 1 and GameES.GetComponent(entityList[1], componentType)[paramName]

				valueField.Image = value == nil and CheckBoxTrueImg or (not value and CheckBoxTrueImg or "")

				PluginES.AddComponent(cLabel, "SerializeParam", {
					Value = value == nil and true or (not value),
					ParamName = paramName,
					ComponentType = componentType,
					EntityList = entityList
				})
			end)
		end
	end)

	PluginES.ComponentAdded("UpdateParamFields", function(updateParamFields)
		local componentLabel = updateParamFields.ComponentLabel

		for _, paramField in ipairs(PluginES.GetListTypedComponent(updateParamFields.Instance, "ParamField")) do
			local entityList = componentLabel.EntityList
			local value = #entityList == 1 and GameES.GetComponent(entityList[1], ComponentDesc.GetComponentTypeFromId(componentLabel.ComponentId))[paramField.ParamName]

		    if paramField.Field:IsA("TextBox") then
			    paramField.Field.Text = value and tostring(value) or ""
		    else
			    paramField.Field.CheckMarkImg = value ~= nil and (value and CheckBoxTrueImg or "") or CheckBoxIndeterminateImg
		    end
		end
	end)
end

return ParamFields

local PluginES
local GameES
local ComponentDesc

local GetColor = settings().Studio.Theme.GetColor

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

		textBox.Size = UDim2.new(0, 0.95, 0, 0.95)
		textBox.AnchorPoint = Vector2.new(0, 0.5)
		textBox.Position = UDim2.new(0, 24, 0, 0)
		textBox.BackgroundColor3 = GetColor(InputFieldBackground)
		textBox.BorderColor3 = GetColor(InputFieldBackground)
		textBox.BorderSizePixel = 1
		textBox.TextColor3 = GetColor(MainText)

		return textBox
	elseif ty == "boolean" then
		local imageButton = Instance.new("ImageButton")
		local imageLabel = Instance.new("ImageLabel")

		imageButton.Size = UDim2.new(24, 0, 24, 0)
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
		local componentType = componentLabel.ComponentType
		local entityList = componentLabel.EntityList
		local componentId = ComponentDesc.GetComponentIdFromType(componentType)
		local paramId = ComponentDesc.GetParamIdFromName(componentId, paramName)
		local ty = typeof(ComponentDesc.GetParamDefault(paramName, componentId))
		local valueField = getElementForValueType(ty)
		local cLabel = paramField.Instance
		local value = #entityList == 1 and GameES.GetComponent(entityList[1], componentType)[paramName]

		valueField.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				fieldContainer.BackgroundColor3 = GetColor(InputFieldBackground, Hover)
				fieldContainer.BorderColor3 = GetColor(InputFieldBorder, Hover)
				label.BackgroundColor3 = GetColor(InputFieldBackground, Hover)
			end
		end)

		valueField.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				fieldContainer.BackgroundColor3 = GetColor(InputFieldBackground)
				fieldContainer.BorderColor3 = GetColor(InputFieldBorder)
				label.BackgroundColor3 = GetColor(InputFieldBackground)
			end
		end)

		if valueField:IsA("TextBox") then
			valueField.Text = value and tostring(value) or ""

			valueField.FocusBegan:Connect(function()
				valueField.BorderColor = GetColor(InputFieldBorder, Selected)
				fieldContainer.BackgroundColor3 = GetColor(InputFieldBackground, Selected)
				fieldContainer.BorderColor = GetColor(InputFieldBorder, Selected)
				label.BackgroundColor3 = GetColor(InputFieldBackground, Selected)
			end)

			valueField.FocusLost:Connect(function()
				local val = types[ty] and types[ty].new(splitCommaDelineatedString(valueField.Text)) or valueField.Text

				valueField.BackgroundColor3 = GetColor(InputFieldBackground)
				valueField.BorderColor3 = GetColor(InputFieldBorder)
				fieldContainer.BackgroundColor3 = GetColor(InputFieldBackground)
				fieldContainer.BorderColor3 = GetColor(InputFieldBorder)
				label.BackgroundColor3 = GetColor(InputFieldBackground)

				value = #entityList == 1 and GameES.GetComponent(entityList[1], componentType)[paramName]

				PluginES.AddComponent(cLabel.Instance, "SerializeParam", {
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

				PluginES.AddComponent(cLabel.Instance, "SerializeParam", {
					Value = value == nil and true or (not value),
					ParamName = paramName,
					ComponentType = componentType,
					EntityList = entityList
				})
			end)
		end

		fieldContainer.Size = UDim2.new(1, 0, 0, 24)
		fieldContainer.Position = UDim2.new(0, 135, 0, 0)
		fieldContainer.BackgroundColor3 = GetColor(InputFieldBackground)
		fieldContainer.BorderColor = GetColor(InputFieldBorder)
		paramField.Field = valueField
		valueField.Parent = fieldContainer
		fieldContainer.Parent = frame

		label.Size = UDim2.new(0, 135, 0, 24)
		label.Text = "     " .. paramName
		label.BorderColor3 = GetColor(Enum.StudioStyleGuideColor.Border)
		label.BackgroundColor3 = GetColor(InputFieldBackground)
		label.TextColor3 = GetColor(MainText)
		label.Parent = frame

		frame.Size = UDim2.new(1, 0, 0, 24)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = paramId
		frame.Parent = cLabel.ParamsContainer
	end)

	PluginES.ComponentAdded("UpdateParamFields", function(updateParamFields)
		for _, paramField in ipairs(PluginES.GetListTypedComponent(updateParamFields.Instance, "ParamField")) do
			local entityList = paramField.ComponentLabel.EntityList
			local value = #entityList == 1 and GameES.GetComponent(entityList[1], paramField.ComponentLabel.ComponentType)[paramField.ParamName]

		    if paramField.Field:IsA("TextBox") then
			    paramField.Field.Text = value and tostring(value) or ""
		    else
			    paramField.Field.CheckMarkImg = value ~= nil and (value and CheckBoxTrueImg or "") or CheckBoxIndeterminateImg
		    end
		end
	end)
end

return ParamFields

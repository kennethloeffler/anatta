local GetColor = settings().Studio.Theme.GetColor
local Serial = require(script.Parent.Parent.Serial)

local ParamFields = {}
local PluginES
local GameES
local ComponentDesc

local InputFieldBorder = Enum.StudioStyleGuideColor.InputFieldBorder
local InputFieldBackground = Enum.StudioStyleGuideColor.InputFieldBackground
local MainText = Enum.StudioStyleGuideColor.MainText

local Selected = Enum.StudioStyleGuideModifier.Selected
local Hover = Enum.StudioStyleGuideModifier.Hover

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
		return Instance.new("TextBox"), ty
	elseif ty == "boolean" then
		return Instance.new("Frame"), ty
	else
		error("Unknown type: " .. ty)
	end
end

function ParamFields.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginES
	GameES = pluginWrapper.GameES

	PluginES.ComponentAdded("ParamField", function(paramField)
		ComponentDesc = GameES.GetComponentDesc()

		local frame = Instance.new("Frame")
		local label = Instance.new("TextLabel")
		local paramId = paramField.ParamId
		local paramValue = paramField.ParamValue
		local paramName = ComponentDesc.GetParamNameFromId(paramField.ComponentId, paramId)
		local valueField = getElementForValueType(typeof(paramValue))
		local componentLabel = paramField.Instance

		valueField.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				valueField.BackgroundColor3 = GetColor(InputFieldBackground, Hover)
				valueField.BorderColor3 = GetColor(InputFieldBorder, Hover)
				label.BackgroundColor3 = GetColor(InputFieldBackground, Hover)
			end
		end)

		valueField.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				valueField.BackgroundColor3 = GetColor(InputFieldBackground)
				valueField.BorderColor3 = GetColor(InputFieldBorder)
				label.BackgroundColor3 = GetColor(InputFieldBackground)
			end
		end)

		if valueField:IsA("TextBox") then
			valueField.Text = tostring(paramValue)

			valueField.FocusBegan:Connect(function()
				valueField.BackgroundColor3 = GetColor(InputFieldBackground, Selected)
				valueField.BorderColor = GetColor(InputFieldBorder, Selected)
				label.BackgroundColor3 = GetColor(InputFieldBackground, Selected)
			end)

			valueField.FocusLost:Connect(function()
				local val = types[typeof(paramValue)].new(splitCommaDelineatedString(valueField.Text)) or paramValue

				valueField.BackgroundColor3 = GetColor(InputFieldBackground)
				valueField.BorderColor3 = GetColor(InputFieldBorder)
				label.BackgroundColor3 = GetColor(InputFieldBackground)

				paramField.ParamValue = val

				PluginES.AddComponent(componentLabel, "SerializeParam", {
					paramField
				})
			end)
		else
			-- make boolean stuff
		end

		paramField.Field = valueField
		valueField.Size = UDim2.new(1, 0, 0, 24)
		valueField.Position = UDim2.new(0, 135, 0, 0)
		valueField.BackgroundColor3 = GetColor(InputFieldBackground)
		valueField.BorderColor = GetColor(InputFieldBorder)
		valueField.Parent = frame

		label.Size = UDim2.new(0, 135, 0, 24)
		label.Text = "     " .. paramName
		label.BorderColor3 = GetColor(Enum.StudioStyleGuideColor.Border)
		label.BackgroundColor3 = GetColor(InputFieldBackground)
		label.TextColor3 = GetColor(MainText)
		label.Parent = frame

		frame.Size = UDim2.new(1, 0, 0, 24)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = paramId
		frame.Parent = componentLabel.ParamsContainer
	end)

	PluginES.ComponentAdded("UpdateParamFields", function(updateParamFields)
		local ty
		local entity = updateParamFields.Entity
		local paramList = updateParamFields.ParamList

		for _, paramField in ipairs(PluginES.GetListTypedComponent(updateParamFields.Instance, "ParamField")) do
			ty = typeof(paramField.ParamValue)

			if paramList[paramField.ParamId] ~= paramField.ParamValue then
				if entity == paramField.Entity then
					paramField.ParamValue = paramList[paramField.ParamId]

					if ty == "string" or ty == "number" or types[ty] then
						paramField.Field.Text = tostring(paramField.ParamValue)
					elseif ty == "boolean" then
						paramField.
					end
				else
					if ty == "string" or ty == "number" or types[ty] then
						paramField.Field.Text = ""
					elseif ty == "boolean" then
					end
				end
			end
		end

		PluginES.KillComponent(updateParamFields)
	end)
end

return ParamFields


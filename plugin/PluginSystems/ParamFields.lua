local Theme = settings().Studio.Theme
local Serial = require(script.Parent.Parent.Serial)

local ParamFields = {}
local PluginES
local GameES
local ComponentDesc

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
	PluginES = pluginWrapper.PluginManager
	GameES = pluginWrapper.GameManager

	PluginES.ComponentAdded("ParamField", function(paramField)
		ComponentDesc = GameES.GetComponentDesc()

		local frame = Instance.new("Frame")
		local label = Instance.new("TextLabel")
		local paramName = ComponentDesc.GetParamNameFromId(paramField.ComponentId, paramField.ParamId)
		local valueField = getElementForValueType(typeof(paramField.ParamValue))

		if valueField:IsA("TextBox") then
			valueField.Text = tostring(paramField.ParamValue)

			valueField.FocusLost:Connect(function()
				local ty = typeof(paramField.ParamValue)
				local val = types[ty].new(splitCommaDelineatedString(valueField.Text))

				GameES.GetComponent(paramField.ComponentType)[paramName] = val
				PluginES.AddComponent(paramField.ComponentLabel.ParentInstance, "DoSerializeEntity")
			end)
		else
			-- make boolean stuff
		end

		paramField.Field = valueField
		valueField.Size = UDim2.new(1, 0, 0, 24)
		valueField.Position = UDim2.new(0, 50, 0, 0)
		valueField.Parent = frame

		label.Size = UDim2.new(0, 50, 0, 24)
		label.Text = "     " .. paramName
		label.BorderColor3 = Theme:GetColor(Enum.StudioStyleGuideColor)
		label.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor)
		label.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor)
		label.LayoutOrder = paramField.ComponentId + paramField.ParamId
		label.Parent = frame

		frame.Size = UDim2.new(1, 0, 0, 24)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Parent = paramField.Instance.Parent
	end)

	PluginES.ComponentAdded("ClearParamFields", function(clearParamFields)
		for _, paramField in ipairs(PluginES.GetListTypedComponent(clearParamFields.ComponentLabel, "ParamField")) do
			paramField.Field.Parent:Destroy()
			PluginES.KillComponent(paramField)
		end
	end)

	PluginES.ComponentAdded("UpdateParamFields", function(updateParamFields)
		local ty

		for _, paramField in ipairs(PluginES.GetListTypedComponent(updateParamFields.ComponentLabel, "ParamField")) do
			ty = typeof(paramField.ParamValue)

			if updateParamFields.ParamList[paramField.ParamId] ~= paramField.ParamValue then
				if updateParamFields.ComponentLabel.ParentInstance == paramField.ParentInstance then
					paramField.ParamValue = updateParamFields.ParamList[paramField.ParamId]

					if ty == "string" or ty == "number" or types[ty] then
						paramField.Field.Text = tostring(paramField.ParamValue)
					elseif ty == "boolean" then
					end
				else
					if ty == "string" or ty == "number" or types[ty] then
						paramField.Field.Text = "..."
					elseif ty == "boolean" then
					end
				end
			end
		end

		PluginES.KillComponent(updateParamFields)
	end)
end

return ParamFields


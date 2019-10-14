local GetColor = settings().Studio.Theme.GetColor
local GameES
local PluginES

local Section = Enum.StudioStyleGuideColor.Section
local MainText = Enum.StudioStyleGuideColor.MainText

local Hover = Enum.StudioStyleGuideModifier.Hover

local ComponentLabels = {}

local function clearParamFields(label)
	for _, paramField in ipairs(PluginES.GetListTypedComponent(label, "ParamField")) do
		PluginES.KillEntity(paramField.Field)
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
		local componentType = componentLabel.ComponentType
		local componentId = componentDesc.GetComponentIdFromType(componentType)
		local label = Instance.new("TextLabel")
		local paramsContainer = Instance.new("Frame")

		PluginES.AddComponent(paramsContainer, "VerticalScalingList")

		label.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if not componentLabel.Open then
					componentLabel.Open = true
					makeParamFields(label, componentLabel, componentDesc.GetDefaults(componentId))
				else
					clearParamFields(label)
					componentLabel.Open = false
				end
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				label.BackgroundColor3 = GetColor(Section, Hover)
			end
		end)

		label.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				label.BackgroundColor3 = GetColor(Section)
			end
		end)

		paramsContainer.Size = UDim2.new(1, 0, 0, 0)
		paramsContainer.Position = UDim2.new(0, 0, 0, 24)
		paramsContainer.BackgroundTransparency = 1
		paramsContainer.BorderSizePixel = 0
		paramsContainer.Name = "ParamsContainer"
		paramsContainer.Parent = label

		label.Size = UDim2.new(1, 0, 0, 24)
		label.BackgroundColor3 = GetColor(Section)
		label.TextColor3 = GetColor(MainText)
		label.Text = ("\t%s"):format(componentType)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Name = componentType
		label.LayoutOrder = componentId
		label.Parent = parentFrame
	end)

	PluginES.ComponentKilled("ComponentLabel", function(componentLabel)
		local label = componentLabel.Instance[componentLabel.ComponentType]

		clearParamFields(label)
		PluginES.KillEntity(label.ParamsContainer)
		PluginES.KillEntity(label)
	end)
end

return ComponentLabels

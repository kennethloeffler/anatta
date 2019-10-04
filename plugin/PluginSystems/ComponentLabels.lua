local GetColor = settings().Studio.Theme.GetColor
local GameES
local PluginES

local Section = Enum.StudioStyleGuideColor.Section
local MainText = Enum.StudioStyleGuideColor.MainText

local Hover = Enum.StudioStyleGuideModifier.Hover

local ComponentLabels = {}

local function clearParamFields(label)
	for _, paramField in ipairs(PluginES.GetListTypedComponent(label, "ParamField")) do
		PluginES.KillComponent(paramField)
		paramField.Field:Destroy()
	end
end

function ComponentLabels.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginES
	GameES = pluginWrapper.GameES

	PluginES.ComponentAdded("ComponentLabel", function(componentLabel)
		local parentFrame = componentLabel.Instance
		local entity = componentLabel.Entity
		local componentType = componentLabel.ComponentType
		local paramList = componentLabel.ParamList
		local oldLabel = parentFrame:FindFirstChild(tostring(componentType))

		if oldLabel then
			PluginES.AddComponent(oldLabel, "UpdateParamFields", {
				entity,
				paramList
			})

			return
		end

		local componentDesc = GameES.GetComponentDesc()
		local componentId = componentDesc.GetComponentIdFromType(componentType)
		local label = Instance.new("TextLabel")
		local paramsContainer = Instance.new("Frame")

		PluginES.AddComponent(paramsContainer, "VerticalScalingList")

		label.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if not componentLabel.Open then
					componentLabel.Open = true

					for paramId, paramValue in ipairs(paramList) do
						PluginES.AddComponent(label, "ParamField", {
							  ComponentId = componentId,
							  ParamId = paramId,
							  ParamValue = paramValue,
							  Entity = entity
						})
					end
				else
					componentLabel.Open = false

					clearParamFields(label)
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
		label.Text = "     " .. componentType
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Name = componentType
		label.LayoutOrder = componentId
		label.Parent = parentFrame
	end)

	PluginES.ComponentAdded("NoSelection", function(noSelection)
		for _, componentLabel in ipairs(PluginES.GetListTypedComponent(noSelection.Instance, "ComponentLabel")) do
			PluginES.KillComponent(componentLabel)
			noSelection.Instance[componentLabel.ComponentType]:Destroy()
		end
	end)
end

return ComponentLabels

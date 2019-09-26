local Theme = settings().Studio.Theme
local GameES
local PluginES

local ComponentLabels = {}

function ComponentLabels.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginManager
	GameES = pluginWrapper.GameManager

	PluginES.ComponentAdded("ComponentLabel", function(componentLabel)
		local parentFrame = componentLabel.Instance
		local componentType = componentLabel.ComponentType

		if parentFrame:FindFirstChild(componentType) then
			PluginES:KillComponent(parentFrame, "ComponentLabel", true)
			return
		end

		local label = Instance.new("TextLabel")
		local paramList = componentLabel.ParamList
		local componentDesc = GameES.GetComponentDesc()
		local labelOpen = false

		label.Size = UDim2.new(1, 0, 0, 24)
		label.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor)
		label.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor)
		label.Text = "     " .. componentType
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Name = componentType
		label.LayoutOrder = componentDesc.GetComponentIdFromType(componentType)

		label.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if not labelOpen then
					labelOpen = true

					for paramId, paramValue in ipairs(paramList) do
						PluginES.AddComponent(label, "ParamField", {
							ComponentType = componentType,
							ParamId = paramId,
							ParamValue = paramValue
						})
					end
				else
					labelOpen = false

					PluginES.AddComponent(label, "ClearParamFields", {
						ComponentType = componentType,
						NumParams = #paramList
					})
				end
			end
		end)

		label.Parent = parentFrame
		PluginES:KillComponent(parentFrame, "ComponentLabel", true)
	end)
end

return ComponentLabels


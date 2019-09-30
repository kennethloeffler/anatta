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
		local componentDesc = GameES.GetComponentDesc()
		local componentId = componentDesc.GetComponentIdFromType(componentType)
		local paramList = componentLabel.ParamList
		local oldLabel = parentFrame:FindFirstChild(tostring(componentId))

		if oldLabel then
			PluginES.AddComponent("UpdateParamFields", {
				oldLabel,
				paramList,
			})

			return
		end

		local label = Instance.new("TextLabel")

		label.Size = UDim2.new(1, 0, 0, 24)
		label.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor)
		label.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor)
		label.Text = "     " .. componentType
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Name = componentId
		label.LayoutOrder = componentId

		label.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if not componentLabel.Open then
					componentLabel.Open = true

					for paramId, paramValue in ipairs(paramList) do
						PluginES.AddComponent(label, "ParamField", {
							componentId,
							paramId,
							paramValue,
							componentLabel.ParentInstance
						})
					end
				else
					componentLabel.Open = false

					PluginES.AddComponent(label, "ClearParamFields", {
						componentId,
						#paramList
					})
				end
			end
		end)

		label.Parent = parentFrame
	end)
end

return ComponentLabels


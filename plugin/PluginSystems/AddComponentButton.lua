local Selection = game:GetService("Selection")

local GetColor = settings().Studio.Theme:GetColor()

local MainText = Enum.StudioStyleGuideColor.MainText
local MainButton = Enum.StudioStyleGuideColor.MainButton
local Border = Enum.StudioStyleGuideColor.Border

local Hover = Enum.StudioStyleGuideModifier.Hover
local Selected = Enum.StudioStyleGuideModifier.Selected

local PluginES

local AddComponentButton = {}

function AddComponentButton.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginES

	PluginES.ComponentAdded("AddComponentButton", function(addComponentButton)
		local componentType = addComponentButton.ComponentType
		local button = Instance.new("TextButton")

		button.Size = UDim2.new(1, 0, 20, 0)
		button.TextColor3 = GetColor(MainText)
		button.BackgroundColor3 = GetColor(MainButton)
		button.BorderColor3 = GetColor(Border)
		button.Name = componentType
		button.Parent = addComponentButton.Instance

		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				button.BackgroundColor3 = GetColor(MainButton, Selected)
				button.BorderColor3 = GetColor(Border, Selected)
				button.TextColor3 = GetColor(MainText, Selected)

				PluginES.AddComponent(button, "SerializeNewComponent", {
					EntityList = Selection:Get(),
					ComponentType = componentType
				})
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				button.BackgroundColor3 = GetColor(MainButton, Hover)
				button.BorderColor3 = GetColor(Border, Hover)
				button.TextColor3 = GetColor(MainText, Hover)
			end
		end)

		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				button.TextColor3 = GetColor(MainText)
				button.BackgroundColor3 = GetColor(MainButton)
				button.BorderColor3 = GetColor(Border)
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				button.TextColor3 = GetColor(MainText)
				button.BackgroundColor3 = GetColor(MainButton)
				button.BorderColor3 = GetColor(Border)
			end
		end)
	end)

	PluginES.ComponentKilled("AddComponentButton", function(addComponentButton)
		local button = addComponentButton.Instance[addComponentButton.ComponentType]

		button:Destroy()
	end)
end

return AddComponentButton
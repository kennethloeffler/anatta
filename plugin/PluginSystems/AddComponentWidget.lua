local Serial = require(script.Parent.Parent.Serial)
local Theme = settings().Studio.Theme
local Selection = game:GetService("Selection")

local AddComponentWidget = {}

local function makeComponentButton(componentType, componentId)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -18, 0, 20)
	button.BorderSizePixel = 0
	button.Text = "     " .. componentType
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
	button.TextSize = 8
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar)
	button.Position = UDim2.new(0, 0, 0, 0)
	button.LayoutOrder = componentId

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			button.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar)
		end
	end)

	return button
end

function AddComponentWidget.OnLoaded(pluginWrapper)
	local PluginManager = pluginWrapper.PluginManager
	local GameManager = pluginWrapper.GameManager

	PluginManager.ComponentAdded("AddComponentMenuClick", function(component)
		local gui = component.Instance
		local uiListLayout = Instance.new("UIListLayout")

		gui.AddComponentButton.Text = "-"
		gui:ClearAllChildren()

		uiListLayout.Parent = gui
		uiListLayout.Padding = UDim.new(0, 1)
		uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder

		for componentType, def in pairs(component.Components) do
			local button = makeComponentButton(componentType, def.ComponentId)

			button.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					button.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar, Enum.StudioStyleGuideModifier.Pressed)
					PluginManager.AddComponent(gui, "DoSerializeEntity", {InstanceList = Selection:Get(), ComponentType = componentType})
				end
			end)

			button.Parent = gui
		end
	end)
end

return AddComponentWidget


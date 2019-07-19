local Serial = require(script.Parent.Parent.Serial)
local Theme = settings().Studio.Theme
local Selection = game:GetService("Selection")

local AddComponentWidget = {}

local function makeComponentButton(componentType, componentId)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -19, 0, 20)
	button.BorderSizePixel = 0
	button.Text = componentType
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

function AddComponentWidget.Init(pluginWrapper)
	local PluginManager = pluginWrapper.PluginManager
	local GameManager = pluginWrapper.GameManager
	
	PluginManager.ComponentAdded("AddComponentMenuClick"):Connect(function(scrollingFrame)
		local component = PluginManager.GetComponent(scrollingFrame, "AddComponentMenuClick")
		scrollingFrame.Parent.AddComponentButton.Text = "-"
		scrollingFrame:ClearAllChildren()
		
		local uiListLayout = Instance.new("UIListLayout")
		uiListLayout.Parent = scrollingFrame
		uiListLayout.Padding = UDim.new(0, 1)
		uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder

		for componentType, def in pairs(component.Components) do
			local button = makeComponentButton(componentType, def.ComponentId)
			button.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					button.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar, Enum.StudioStyleGuideModifier.Pressed)
					local selection = Selection:Get()
					for _, instance in ipairs(selection) do
						local module = instance:FindFirstChild("__WSEntity")
						if not module then
							module = Instance.new("ModuleScript")
							module.Name = "__WSEntity"
							module.Parent = instance
						end
						local addedComponent = GameManager.AddComponent(instance, componentType)
						local struct = module and Serial.Deserialize(module.Source) or {}
						struct[addedComponent._componentId] = {}
						struct.Entity = addedComponent._entity
						for index, value in pairs(addedComponent) do
							if typeof(index) == "number" then 
								struct[addedComponent._componentId][index] = value
							end
						end
						module.Source = Serial.Serialize(struct)
					end
				end
			end)
			button.Parent = scrollingFrame
		end
	end)
end

return AddComponentWidget


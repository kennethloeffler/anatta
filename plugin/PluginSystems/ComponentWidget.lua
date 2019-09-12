local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local Theme = settings().Studio.Theme

local GameRoot = ReplicatedStorage:FindFirstChild("WorldSmith")
local GameComponentDesc = GameRoot and GameRoot.ComponentDesc
local ComponentDefs = GameComponentDesc:FindFirstChild("ComponentDefinitions") and GameComponentDesc.ComponentDefinitions

local Serial = require(script.Parent.Parent.Serial)

local ComponentWidget = {}

function ComponentWidget.OnLoaded(pluginWrapper)
	local GameManager = pluginWrapper.GameManager
	local PluginManager = pluginWrapper.PluginManager
	local toolbar = pluginWrapper.GetToolbar("WorldSmith")
	local referenceButton = pluginWrapper.GetButton(toolbar, "WSReplicatorReference")
	local prefabButton = pluginWrapper.GetButton(toolbar, "WSPrefabRootInstance")
	local entities = {}

	local widget = pluginWrapper.GetDockWidget("Components", Enum.InitialDockState.Float, true, false,  200, 300)
	widget.Title = "Components"

	local bgFrame = Instance.new("Frame")
	bgFrame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BorderSizePixel = 0
	PluginManager.AddComponent(bgFrame, "ComponentWidget", {})
	bgFrame.Parent = widget

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.TopImage = ""
	scrollingFrame.BottomImage = ""
	scrollingFrame.ScrollBarImageColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Light)
	scrollingFrame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 16
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.Position = UDim2.new(0, 0, 0, 1)
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, 0)
	scrollingFrame.Parent = bgFrame

	local AddComponentButton = Instance.new("TextButton")
	AddComponentButton.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar)
	AddComponentButton.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainText)
	AddComponentButton.AutoButtonColor = false
	AddComponentButton.Text = "+"
	AddComponentButton.TextSize = 18
	AddComponentButton.Font = Enum.Font.Code
	AddComponentButton.TextYAlignment = Enum.TextYAlignment.Bottom
	AddComponentButton.BorderSizePixel = 0
	AddComponentButton.Size = UDim2.new(0, 16, 0, 16)
	AddComponentButton.Position = UDim2.new(1, -17, 0, 1)
	AddComponentButton.Name = "AddComponentButton"
	AddComponentButton.Parent = bgFrame

	AddComponentButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			AddComponentButton.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar, Enum.StudioStyleGuideModifier.Pressed)

			if not PluginManager.GetComponent(scrollingFrame, "AddComponentMenuClick") then
				PluginManager.AddComponent(scrollingFrame, "AddComponentMenuClick", {Components = Serial.Deserialize(ComponentDefs.Source)})
			else
				scrollingFrame:ClearAllChildren()
				AddComponentButton.Text = "+"
				PluginManager.KillComponent(scrollingFrame, "AddComponentMenuClick")
				PluginManager.AddComponent(scrollingFrame, "SelectionUpdate", {EntityList = entities})
			end
		end
	end)

	AddComponentButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			AddComponentButton.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar)
		end
	end)

	scrollingFrame.ChildAdded:Connect(function(child)
		if not child:IsA("GuiBase") then
			return
		end

		scrollingFrame.CanvasSize = scrollingFrame.CanvasSize + UDim2.new(0, 0, 0, child.AbsoluteSize.Y)
	end)

	scrollingFrame.ChildRemoved:Connect(function(child)
		if not child:IsA("GuiBase") then
			return
		end

		scrollingFrame.CanvasSize = scrollingFrame.CanvasSize - UDim2.new(0, 0, 0, child.AbsoluteSize.Y)
	end)

	referenceButton.Click:Connect(function()
		for _, instance in ipairs(entities) do
			if CollectionService:HasTag(instance, "__WSEntity") then
				if not CollectionService:HasTag(instance, "__WSReplicatorRef") then
					CollectionService:AddTag(instance, "__WSReplicatorRef")
				else
					CollectionService:RemoveTag(instance, "__WSReplicatorRef")
				end
			end
		end
	end)

	prefabButton.Click:Connect(function()
		for _, instance in ipairs(entities) do
			if not CollectionService:HasTag(instance, "__WSReplicatorRoot") then
				CollectionService:AddTag(instance, "__WSReplicatorRoot")
			else
				CollectionService:RemoveTag(instance, "__WSReplicatorRoot")
			end
		end
	end)

	Selection.SelectionChanged:Connect(function()
		local selectedInstances = Selection:Get()

		if not next(selectedInstances) then
			scrollingFrame:ClearAllChildren()
			widget.Title = "Components"
			return
		end

		entities = {}

		if #selectedInstances > 1 then
			widget.Title = "Components - " .. #selectedInstances .. " items"
		else
			widget.Title = "Components - " .. selectedInstances[1].ClassName .. " \"" .. selectedInstances[1].Name .. "\""
		end

		for _, inst in ipairs(selectedInstances) do
			entities[#entities + 1] = inst
		end

		if not PluginManager.GetComponent(scrollingFrame, "AddComponentMenuClick") then
			PluginManager.AddComponent(scrollingFrame, "SelectionUpdate", {EntityList = entities})
		end
	end)
end

return ComponentWidget


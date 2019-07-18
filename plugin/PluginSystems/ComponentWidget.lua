local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local Theme = settings().Studio.Theme

local GameRoot = ReplicatedStorage:FindFirstChild("WorldSmith")
local GameComponentDesc = GameRoot and require(GameRoot.ComponentDesc)
local ComponentWidget = {}

function ComponentWidget.Init(pluginWrapper)
	local GameManager = pluginWrapper.GameManager
	local PluginManager = pluginWrapper.PluginManager
	local widget = pluginWrapper.GetDockWidget("Components", Enum.InitialDockState.Float, true, false,  200, 300)
	widget.Title = "Components"
	
	local bgFrame = Instance.new("Frame")
	bgFrame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	PluginManager.AddComponent(bgFrame, "ComponentWidget", {})
	bgFrame.Parent = widget

	local AddComponentButton = Instance.new("TextButton")
	AddComponentButton.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Button)
	AddComponentButton.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainText)
	AddComponentButton.Text = "+"
	AddComponentButton.TextSize = 20
	AddComponentButton.BorderSizePixel = 0
	AddComponentButton.Size = UDim2.new(0, 32, 0, 32)
	AddComponentButton.Position = UDim2.new(1, -32, 0, 0)
	AddComponentButton.Parent = bgFrame

	AddComponentButton.MouseButton1Down:Connect(function()
		local components = GameComponentDesc.GetAllComponents()
		print("clicked")
		PluginManager.AddComponent(bgFrame, "AddComponentMenuOpen", {Components = components})
	end)
	
	Selection.SelectionChanged:Connect(function()
		local selectedInstances = Selection:Get()

		if not next(selectedInstances) then
			widget.Title = "Components"
			return
		end

		if #selectedInstances > 1 then
			widget.Title = "Components - " .. #selectedInstances .. " items"
		else
			widget.Title = "Components - " .. selectedInstances[1].ClassName .. " \"" .. selectedInstances[1].Name .. "\""
		end

		local entities = {}
		for _, inst in ipairs(selectedInstances) do
			local entity = GameManager:GetEntity(inst)
			if entity then
				entities[#entities + 1] = inst
			end
		end
	
		PluginManager.AddComponent(bgFrame, "SelectionUpdate", {EntityList = entities})
	end)
end

return ComponentWidget


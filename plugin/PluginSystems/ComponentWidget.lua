local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local Theme = settings().Studio.Theme

local GameRoot = ReplicatedStorage:FindFirstChild("WorldSmith")
local GameComponentDesc = GameRoot and require(GameRoot.ComponentDesc)
local ComponentWidget = {}

function ComponentWidget.Init(plugin)
	local GameManager = plugin.GameManager
	local PluginManager = plugin.PluginManager
	local widget = plugin.GetDockWidget("Components", Enum.InitialDockState.Float, true, false,  200, 300)
	widget.Title = "Components"
	
	local bgFrame = Instance.new("Frame")
	bgFrame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	PluginManager.AddComponent(bgFrame, "ComponentWidget", {})
	bgFrame.Parent = widget

	local AddComponentButton = Instance.new("TextButton")
	AddComponentButton.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Button)
	AddComponentButton.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainText)
	AddComponentButton.TextStrokeTransparency = 1
	AddComponentButton.Text = "+"
	AddComponentButton.Size = UDim2.new(0, 100, 0, 100)
	AddComponentButton.Position = UDim2.new(1, 0, 0, 0)
	AddComponentButton.AnchorPoint = Vector2.new(0.5, 0.5)
	AddComponentButton.Parent = bgFrame

	AddComponentButton.MouseButton1Down:Connect(function()
		local components = GameComponentDesc.GetAllComponents()
		local addComponentWidget = plugin.GetDockWidget("AddComponents", EnumInitialDockState.Float, true, false, 200, 300)
		addComponentWidget.Title = "Add components"

		local bgFrame = Instance.new("Frame")
		bgFrame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		bgFrame.Size = UDim2.new(1, 0, 1, 0)
		bgFrame.Parent = addComponentWidget

		PluginManager.AddComponent(bgFrame, "AddComponentMenuOpen", {Components = components})
		
		addComponentWidget:BindToClose(function()
			addComponentWidget:Destroy()
		end)
	end)
	
	Selection.SelectionChanged:Connect(function()
		local selectedInstances = Selection:Get()

		if #selectedInstances > 1 then
			widget.Title = "Components - " .. #selectedInstances .. " items"
		else
			widget.Title = "Components - " .. selectedInstances[1].Name
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

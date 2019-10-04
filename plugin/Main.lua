-- Main.lua
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")

local Serial = require(script.Parent.Serial)
local GetColor = settings().Studio.Theme.GetColor
local GameES
local PluginES

local function collectPluginComponents(root)
	-- PluginComponents are not persistent
	local numPluginComponents = 0
	local componentDefinitions = {}
	local components = root.plugin.PluginComponents
	local componentDefsModule = root.src.ComponentDesc:WaitForChild("ComponentDefinitions", 2) or Instance.new("ModuleScript")

	for _, componentModule in ipairs(components:GetChildren()) do
		local rawComponent = require(componentModule)
		local componentType = typeof(rawComponent[1]) == "table" and rawComponent[1][1] or rawComponent[1]
		local paramMap = rawComponent[2]
		local paramId = 1

		numPluginComponents = numPluginComponents + 1
		componentDefinitions[componentType] = {}
		componentDefinitions[componentType][1] = numPluginComponents

		for paramName, defaultValue in pairs(paramMap) do
			paramId = paramId + 1
			componentDefinitions[componentType][paramId] = { ["paramName"] = paramName, ["defaultValue"] = defaultValue }
		end
	end

	componentDefsModule.Name = "ComponentDefinitions"
	componentDefsModule.Source = Serial.Serialize(componentDefinitions)
	componentDefsModule.Parent = root.src.ComponentDesc
end

return function(pluginWrapper, root, gameRoot)
	local mainToolbar = pluginWrapper.GetToolbar("WorldSmith")
	local addComponentButton = pluginWrapper.GetButton(mainToolbar, "Add component...", "Displays/hides a menu which can be used to add components to instances")
	local listComponentButton = pluginWrapper.GetButton(mainToolbar, "List components...", "Displays/hides a menu which can be used to view components on selected instances, edit their parameters, or remove them")

	local networkToolbar = pluginWrapper.GetToolbar("WorldSmith replicator")
	local makeReferenceButton = pluginWrapper.GetButton(networkToolbar, "Make reference", "Tags the selected entities with an EntityReplicator reference")
	local removeReferenceButton = pluginWrapper.GetButton(networkToolbar, "Remove reference", "Removes the EntityReplicator reference from the selected entities")
	local makePrefabButton = pluginWrapper.GetButton(networkToolbar, "Make root instance", "Tags the selected instances as being an EntityReplicator prefab root instance")
	local removePrefabButton = pluginWrapper.GetButton(networkToolbar, "Remove root instance", "Removes the EntityReplicator root instance tag from the selected instances")

	local systems = root.plugin.PluginSystems
	local componentListWidget = pluginWrapper.GetDockWidget("Components", Enum.InitialDockState.Float, true, false,  200, 300)
	local addComponentWidget = pluginWrapper.GetDockWidget("AddComponents", Enum.InitialDockState.Float, true, false, 200, 300)
	local scrollingFrame = Instance.new("ScrollingFrame")
	local selected = Selection:Get()

	componentListWidget.Title = "Components"
	addComponentWidget.Title = "Add components"

	scrollingFrame.TopImage = ""
	scrollingFrame.BottomImage = ""
	scrollingFrame.ScrollBarImageColor3 = GetColor(Enum.StudioStyleGuideColor.Light)
	scrollingFrame.BackgroundColor3 = GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 16
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.Position = UDim2.new(0, 0, 0, 1)
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, 0)
	scrollingFrame.Parent = componentListWidget

	PluginES.AddComponent(scrollingFrame, "VerticalScalingList")

	Selection.SelectionChanged:Connect(function()
		selected = Selection:Get()

		local numSelected = #selected
		local module

		if numSelected == 0 then
			componentListWidget.Title = "Components"

			PluginES.AddComponent(scrollingFrame, "NoSelection")

			return
		elseif numSelected == 1 then
			componentListWidget.Title = ("Components - %s items"):format(numSelected)
		else
			componentListWidget.Title = ("Components - %s \"%s\""):format(selected[1].ClassName, selected[1].Name)
		end

		for _, instance in ipairs(selected) do
			module = instance:FindFirstChild("__WSEntity")

			if module then
				for componentType, paramList in pairs(Serial.Deserialize(module.Source)) do
					PluginES.AddComponent(scrollingFrame, "ComponentLabel", {
						ComponentType = componentType,
						ParamList = paramList,
						Entity = instance
					})
				end
			end
		end
	end)

	makeReferenceButton.Click:Connect(function()
		for _, instance in ipairs(selected) do
			if CollectionService:HasTag(instance, "__WSEntity") then
				CollectionService:AddTag(instance, "__WSReplicatorRef")
			end
		end
	end)

	makePrefabButton.Click:Connect(function()
		for _, instance in ipairs(selected) do
			CollectionService:AddTag(instance, "__WSReplicatorRoot")
		end
	end)

	removeReferenceButton.Click:Connect(function()
		for _, instance in ipairs(selected) do
			if CollectionService:HasTag(instance, "__WSEntity") then
				CollectionService:RemoveTag(instance, "__WSReplicatorRef")
			end
		end
	end)

	removePrefabButton.Click:Connect(function()
		for _, instance in ipairs(selected) do
			CollectionService:RemoveTag(instance, "__WSReplicatorRoot")
		end
	end)

	listComponentButton.Click:Connect(function()
		componentListWidget.Enabled = not componentListWidget.Enabled
	end)

	addComponentButton.Click:Connect(function()
		addComponentWidget.Enabled = not addComponentWidget.Enabled
	end)

	collectPluginComponents(root)

	PluginES = require(root.src.EntityManager)

	PluginES.LoadSystem(systems.GameComponentLoader, pluginWrapper)

	GameES = gameRoot and require(gameRoot.EntityManager)

	pluginWrapper.GameES = GameES
	pluginWrapper.PluginES = PluginES

	PluginES.LoadSystem(systems.GameEntityBridge, pluginWrapper)
	PluginES.LoadSystem(systems.VerticalScalingList, pluginWrapper)
	PluginES.LoadSystem(systems.ComponentLabels, pluginWrapper)
	PluginES.LoadSystem(systems.ParamFields, pluginWrapper)

	GameES.Init()

	pluginWrapper.OnUnloading = function()
		local dockWidget = pluginWrapper.GetDockWidget("Components")

		PluginES.Destroy()
		GameES.Destroy()

		if dockWidget then
			dockWidget:ClearAllChildren()
		end
	end

	coroutine.wrap(PluginES.StartSystems)()
end

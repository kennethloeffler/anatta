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
	local systems = root.plugin.PluginSystems
	local selectedInstances = {}
	local widget = pluginWrapper.GetDockWidget("Components", Enum.InitialDockState.Float, true, false,  200, 300)
	local toolbar = pluginWrapper.GetToolbar("WorldSmith")
	local scrollingFrame = Instance.new("ScrollingFrame")
	local makeReferenceButton = pluginWrapper.GetButton(toolbar, "Make reference", "Tags the selected entities with an EntityReplicator reference")
	local removeReferenceButton = pluginWrapper.GetButton(toolbar, "Remove reference", "Removes the EntityReplicator reference from the selected entities")
	local makePrefabButton = pluginWrapper.GetButton(toolbar, "Make root instance", "Tags the selected instances as being an EntityReplicator prefab root instance")
	local removePrefabButton = pluginWrapper.GetButton(toolbar, "Remove root instance", "Removes the EntityReplicator root instance tag from the selected instances")

	widget.Title = "Components"

	scrollingFrame.TopImage = ""
	scrollingFrame.BottomImage = ""
	scrollingFrame.ScrollBarImageColor3 = GetColor(Enum.StudioStyleGuideColor.Light)
	scrollingFrame.BackgroundColor3 = GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 16
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.Position = UDim2.new(0, 0, 0, 1)
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, 0)
	scrollingFrame.Parent = widget

	PluginES.AddComponent(scrollingFrame, "VerticalScalingList")

	Selection.SelectionChanged:Connect(function()
		local selected = Selection:Get()
		local numSelected = #selected
		local module

		if numSelected == 0 then
			PluginES.AddComponent(scrollingFrame, "NoSelection")
			widget.Title = "Components"
			return
		end

		if numSelected > 1 then
			widget.Title = ("Components - %s items"):format(numSelected)
		else
			widget.Title = ("Components - %s \"%s\""):format(selected[1].ClassName, selectedInstances[1].Name)
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
		for _, instance in ipairs(selectedInstances) do
			if CollectionService:HasTag(instance, "__WSEntity") then
				CollectionService:AddTag(instance, "__WSReplicatorRef")
			end
		end
	end)

	makePrefabButton.Click:Connect(function()
		for _, instance in ipairs(selectedInstances) do
			CollectionService:AddTag(instance, "__WSReplicatorRoot")
		end
	end)

	removeReferenceButton.Click:Connect(function()
		for _, instance in ipairs(selectedInstances) do
			if CollectionService:HasTag(instance, "__WSEntity") then
				CollectionService:RemoveTag(instance, "__WSReplicatorRef")
			end
		end
	end)

	removePrefabButton.Click:Connect(function()
		for _, instance in ipairs(selectedInstances) do
			CollectionService:RemoveTag(instance, "__WSReplicatorRoot")
		end
	end)

	collectPluginComponents(root)

	PluginES = require(root.src.EntityManager)

	PluginES.LoadSystem(systems.GameComponentLoader, pluginWrapper)

	GameES = gameRoot and require(gameRoot.EntityManager)

	pluginWrapper.GameES = GameES
	pluginWrapper.PluginES = PluginES

	PluginES.LoadSystem(systems.ComponentWidget, pluginWrapper)
	PluginES.LoadSystem(systems.AddComponentWidget, pluginWrapper)
	PluginES.LoadSystem(systems.EntityPersistence, pluginWrapper)
	PluginES.LoadSystem(systems.ComponentWidgetList, pluginWrapper)

	GameES.Init()

	pluginWrapper.OnUnloading = function()
		local dockWidget = pluginWrapper.GetDockWidget("Components")

		if dockWidget then
			dockWidget:ClearAllChildren()
		end

		PluginES.Destroy()
		GameES.Destroy()
	end

	coroutine.wrap(PluginES.StartSystems)()
end


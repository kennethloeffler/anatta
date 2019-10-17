-- Main.lua

-- Copyright 2019 Kenneth Loeffler

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")

local Serial = require(script.Parent.Serial)
local Theme = settings().Studio.Theme
local GameES
local PluginES

local function collectPluginComponents(root)
	-- PluginComponents are not persistent
	local numPluginComponents = 0
	local componentDefinitions = {}
	local components = root.plugin.PluginComponents
	local componentDefsModule = root.src.ComponentDesc:WaitForChild("ComponentDefinitions", 2) or Instance.new("ModuleScript")

	for _, componentModule in ipairs(components:GetChildren()) do
		numPluginComponents = numPluginComponents + 1

		local rawComponent = require(componentModule)
		local listTyped = typeof(rawComponent[1]) == "table"
		local componentType = listTyped and rawComponent[1][1] or rawComponent[1]
		local componentIdStr = tostring(numPluginComponents)
		local paramMap = rawComponent[2]
		local paramId = 1

		componentDefinitions[componentIdStr] = {}
		componentDefinitions[componentIdStr][1] = { ComponentType = componentType, ListType = listTyped }

		for paramName, defaultValue in pairs(paramMap) do
			paramId = paramId + 1
			componentDefinitions[componentIdStr][paramId] = { ParamName = paramName, DefaultValue = defaultValue }
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
	local selected = Selection:Get()
	local componentListWidget = pluginWrapper.GetDockWidget("Components", Enum.InitialDockState.Float, true, false,  200, 300)
	local addComponentWidget = pluginWrapper.GetDockWidget("Add components", Enum.InitialDockState.Float, true, false, 200, 300)
	local scrollingFrame = Instance.new("ScrollingFrame")

	collectPluginComponents(root)

	PluginES = require(root.src.EntityManager)
	pluginWrapper.PluginES = PluginES

	PluginES.LoadSystem(systems.GameComponentLoader, pluginWrapper)

	GameES = gameRoot and require(gameRoot.EntityManager)
	pluginWrapper.GameES = GameES

	PluginES.LoadSystem(systems.GameEntityBridge, pluginWrapper)
	PluginES.LoadSystem(systems.AddComponentButton, pluginWrapper)
	PluginES.LoadSystem(systems.VerticalScalingList, pluginWrapper)
	PluginES.LoadSystem(systems.ComponentLabels, pluginWrapper)
	PluginES.LoadSystem(systems.ParamFields, pluginWrapper)

	GameES.Init()


	componentListWidget.Title = "Components"
	addComponentWidget.Title = "Add components"

	PluginES.AddComponent(scrollingFrame, "VerticalScalingList")

	scrollingFrame.TopImage = ""
	scrollingFrame.BottomImage = ""
	scrollingFrame.ScrollBarImageColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Light)
	scrollingFrame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 16
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.Position = UDim2.new(0, 0, 0, 1)
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, 0)
	scrollingFrame.Parent = componentListWidget

	coroutine.wrap(PluginES.StartSystems)()

	Selection.SelectionChanged:Connect(function()
		selected = Selection:Get()

		local numSelected = #selected
		local instancesByComponentId = {}
		local t
		local module

		if numSelected == 0 then
			componentListWidget.Title = "Components"
		elseif numSelected == 1 then
			componentListWidget.Title = ("Components - %s \"%s\""):format(selected[1].ClassName, selected[1].Name)
		else
			componentListWidget.Title = ("Components - %s items"):format(numSelected)
		end

		for _, instance in ipairs(selected) do
			module = instance:FindFirstChild("__WSEntity")

			if module then
				for _, component in pairs(GameES.GetComponents(instance)) do
					t = instancesByComponentId[component._componentId] or {}
					instancesByComponentId[component._componentId] = t
					t[#t + 1] = instance
				end
			end
		end

		for _, componentLabel in ipairs(PluginES.GetListTypedComponent(scrollingFrame, "ComponentLabel")) do
			local componentId = componentLabel.ComponentId

			if not instancesByComponentId[componentId] then
				PluginES.KillComponent(componentLabel)
			else
				componentLabel.EntityList = instancesByComponentId[componentId]
				PluginES.AddComponent(componentLabel.Instance[componentId], "UpdateParamFields", {componentLabel})
				instancesByComponentId[componentId] = nil
			end
		end

		for componentId, entityList in pairs(instancesByComponentId) do
			PluginES.AddComponent(scrollingFrame, "ComponentLabel", {
				ComponentId = componentId,
				EntityList = entityList
			})
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

	pluginWrapper.OnUnloading = function()
		local listWidget = pluginWrapper.GetDockWidget("Components")
		local addWidget = pluginWrapper.GetDockWidget("Add components")

		PluginES.Destroy()
		GameES.Destroy()

		if listWidget then
			listWidget:ClearAllChildren()
		end

		if addWidget then
			addWidget:ClearAllChildren()
		end
	end
end

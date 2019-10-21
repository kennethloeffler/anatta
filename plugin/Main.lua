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
	local networkToolbar = pluginWrapper.GetToolbar("WorldSmith replicator")
	local makeReferenceButton = pluginWrapper.GetButton(networkToolbar, "Make reference", "Tags the selected entities with an EntityReplicator reference")
	local removeReferenceButton = pluginWrapper.GetButton(networkToolbar, "Remove reference", "Removes the EntityReplicator reference from the selected entities")
	local makePrefabButton = pluginWrapper.GetButton(networkToolbar, "Make root instance", "Tags the selected instances as being an EntityReplicator prefab root instance")
	local removePrefabButton = pluginWrapper.GetButton(networkToolbar, "Remove root instance", "Removes the EntityReplicator root instance tag from the selected instances")

	local systems = root.plugin.PluginSystems

	collectPluginComponents(root)

	PluginES = require(root.src.EntityManager)
	pluginWrapper.PluginES = PluginES

	PluginES.LoadSystem(systems.VerticalScalingList, pluginWrapper)
	PluginES.LoadSystem(systems.GameComponentLoader, pluginWrapper)
	PluginES.LoadSystem(systems.AddComponentWidget, pluginWrapper)

	GameES = gameRoot and require(gameRoot.EntityManager)
	pluginWrapper.GameES = GameES

	GameES.Init()

	PluginES.LoadSystem(systems.GameEntityBridge, pluginWrapper)
	PluginES.LoadSystem(systems.ComponentLabels, pluginWrapper)
	PluginES.LoadSystem(systems.ParamFields, pluginWrapper)
	PluginES.LoadSystem(systems.ComponentListWidget, pluginWrapper)

	coroutine.wrap(PluginES.StartSystems)()
	coroutine.wrap(GameES.StartSystems)()

	makeReferenceButton.Click:Connect(function()
		for _, instance in ipairs(Selection:Get()) do
			if CollectionService:HasTag(instance, "__WSEntity") then
				CollectionService:AddTag(instance, "__WSReplicatorRef")
			end
		end
	end)

	makePrefabButton.Click:Connect(function()
		for _, instance in ipairs(Selection:Get()) do
			CollectionService:AddTag(instance, "__WSReplicatorRoot")
		end
	end)

	removeReferenceButton.Click:Connect(function()
		for _, instance in ipairs(Selection:Get()) do
			if CollectionService:HasTag(instance, "__WSEntity") then
				CollectionService:RemoveTag(instance, "__WSReplicatorRef")
			end
		end
	end)

	removePrefabButton.Click:Connect(function()
		for _, instance in ipairs(Selection:Get()) do
			CollectionService:RemoveTag(instance, "__WSReplicatorRoot")
		end
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

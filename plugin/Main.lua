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

local GameES
local PluginES

local function popPluginComponents(root)
	-- PluginComponents are not persistent
	local numPluginComponents = 0
	local componentDefinitions = {}
	local components = root.plugin.PluginComponents

	for _, componentModule in ipairs(components:GetChildren()) do
		numPluginComponents = numPluginComponents + 1

		local rawComponent = require(componentModule)
		local listTyped = typeof(rawComponent[1]) == "table"
		local componentType = listTyped and rawComponent[1][1] or rawComponent[1]
		local componentIdStr = tostring(numPluginComponents)
		local paramMap = rawComponent[2]
		local componentDefinition = { { ComponentType = componentType, ListType = listTyped } }
		local paramId = 1

		for paramName, defaultValue in pairs(paramMap) do
			paramId = paramId + 1
			componentDefinition[paramId] = { ParamName = paramName, DefaultValue = defaultValue }
		end

		componentDefinitions[componentIdStr] = componentDefinition
	end

	root.src.ComponentDesc:SetAttribute("__WSComponentDefinitions", componentDefinitions)
end

return function(pluginWrapper, root, gameRoot)
	local systems = root.plugin.PluginSystems

	popPluginComponents(root)

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

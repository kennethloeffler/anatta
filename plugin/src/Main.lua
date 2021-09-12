local CollectionService = game:GetService("CollectionService")

local Anatta = require(script.Parent.Parent.Anatta)
local PluginComponents = require(script.Parent.PluginComponents)
local Constants = require(script.Parent.Constants)
local Systems = script.Parent.Systems
local t = Anatta.t

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local DEFINITION_CONTAINER_TAG_NAME = Constants.DefinitionModuleTagName
local PENDING_VALIDATION = Constants.PendingValidation
local SHARED_INSTANCE_TAG_NAME = Constants.SharedInstanceTagName

local function loadDefinition(plugin, loader, moduleScript)
	if not moduleScript:IsA("ModuleScript") then
		warn(("Components definition instance %s must be a ModuleScript"):format(moduleScript:GetFullName()))
		return
	end

	local clone = moduleScript:Clone()
	local componentDefinition = require(clone)
	local name = componentDefinition.name
	local type

	if componentDefinition.meta ~= nil and componentDefinition.meta.plugin ~= nil then
		type = componentDefinition.meta.plugin.type
	else
		type = componentDefinition.type
	end

	if not loader.registry:hasDefined(name) then
		local pendingValidation = PENDING_VALIDATION:format(name)

		loader.registry:define(name, type)
		loader.registry:define(pendingValidation, t.none)

		loader:loadSystem(Systems.AttributeValidator, name, pendingValidation)
		loader:loadSystem(Systems.AttributeListener, name, pendingValidation, plugin:getMouse())
		loader:loadSystem(Systems.Component, name, pendingValidation)
	else
		warn(("Found duplicate component name %s in %s; skipping"):format(
			name,
			moduleScript:GetFullName()
		))
	end
end

local function loadDefinitionContainer(plugin, loader, container, connections)
	for _, moduleScript in ipairs(container:GetChildren()) do
		loadDefinition(plugin, loader, moduleScript)

		table.insert(
			connections,
			moduleScript.Changed:Connect(function(propertyName)
				if propertyName == "Source" then
					plugin:reload()
				end
			end)
		)
	end

	table.insert(
		connections,
		container.ChildAdded:Connect(function(moduleScript)
			loadDefinition(plugin, loader, moduleScript)
		end)
	)
end

return function(plugin, saveState)
	local loader = Anatta.Loader.new(PluginComponents)
	local definitionContainerAdded =
		CollectionService:GetInstanceAddedSignal(DEFINITION_CONTAINER_TAG_NAME)
	local connections = {}

	plugin:activate(false)

	for _, container in ipairs(CollectionService:GetTagged(DEFINITION_CONTAINER_TAG_NAME)) do
		loadDefinitionContainer(plugin, loader, container, connections)
	end

	table.insert(
		connections,
		definitionContainerAdded:Connect(function(container)
			loadDefinitionContainer(plugin, loader, container, connections)
		end)
	)

	loader:loadSystem(Systems.Entity)

	if saveState then
		loader.registry:load(saveState)

		loader.registry:each(function(entity)
			loader.registry:tryRemove(entity, ".anattaValidationListener")
		end)
	else
		local success, result = Anatta.Dom.tryFromDom(loader.registry)

		if not success then
			warn(result)
		else
			for _, instance in ipairs(CollectionService:GetTagged(SHARED_INSTANCE_TAG_NAME)) do
				local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

				if loader.registry:valid(entity) then
					loader.registry:add(entity, ".anattaInstance", instance)
				end
			end
		end
	end

	plugin:beforeUnload(function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		plugin:deactivate()
		loader:unloadAllSystems()

		return loader.registry
	end)
end

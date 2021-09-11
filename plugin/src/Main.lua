local CollectionService = game:GetService("CollectionService")

local Anatta = require(script.Parent.Parent.Anatta)
local PluginComponents = require(script.Parent.PluginComponents)
local Constants = require(script.Parent.Constants)
local Systems = script.Parent.Systems
local t = Anatta.t

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local DEFINITION_MODULE_TAG_NAME = Constants.DefinitionModuleTagName
local PENDING_VALIDATION = Constants.PendingValidation

local function loadDefinition(moduleScript, loader, plugin)
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
		continue
	end
end

return function(plugin, saveState)
	local loader = Anatta.Loader.new(PluginComponents)
	local componentModuleAdded =
		CollectionService:GetInstanceAddedSignal(DEFINITION_MODULE_TAG_NAME)
	local componentChangedConnections = {}

	plugin:activate(false)

	table.insert(
		componentChangedConnections,
		componentModuleAdded:Connect(function(moduleScript)
			loadDefinition(moduleScript, loader, plugin)
		end)
	)

	for _, moduleScript in ipairs(CollectionService:GetTagged(DEFINITION_MODULE_TAG_NAME)) do
		loadDefinition(moduleScript, loader, plugin)

		table.insert(moduleScript.Changed:Connect(function(propertyName)
			if propertyName == "Source" then
				plugin:reload()
			end
		end))
	end

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
			for _, instance in ipairs(CollectionService:GetTagged(".anattaInstance")) do
				local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

				if loader.registry:valid(entity) then
					loader.registry:add(entity, ".anattaInstance", instance)
				end
			end
		end
	end

	plugin:beforeUnload(function()
		for _, connection in ipairs(componentChangedConnections) do
			connection:Disconnect()
		end

		plugin:deactivate()
		loader:unloadAllSystems()

		return loader.registry
	end)
end

local CollectionService = game:GetService("CollectionService")

local Anatta = require(script.Parent.Parent.Anatta)
local PluginComponents = require(script.Parent.PluginComponents)
local Constants = require(script.Parent.Constants)
local Systems = script.Parent.Systems
local t = Anatta.t

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local DEFINITION_MODULE_TAG_NAME = Constants.DefinitionModuleTagName
local PENDING_VALIDATION = Constants.PendingValidation

local function loadDefinitions(moduleScript, anatta, plugin)
	if not moduleScript:IsA("ModuleScript") then
		warn(("Components definition instance %s must be a ModuleScript"):format(moduleScript:GetFullName()))
		return
	end

	local clone = moduleScript:Clone()
	clone.Parent = moduleScript.Parent
	moduleScript:Destroy()

	local componentDefinitions = require(clone)

	for componentName, typeDefinition in pairs(componentDefinitions) do
		if not anatta.registry:hasDefined(componentName) then
			local pendingValidation = PENDING_VALIDATION:format(componentName)

			anatta.registry:define(componentName, typeDefinition)
			anatta.registry:define(pendingValidation, t.none)

			anatta:loadSystem(Systems.AttributeValidator, componentName, pendingValidation)
			anatta:loadSystem(
				Systems.AttributeListener,
				componentName,
				pendingValidation,
				plugin:getMouse()
			)
			anatta:loadSystem(Systems.Component, componentName, pendingValidation)
		else
			warn(("Found duplicate component name %s in %s; skipping"):format(
				componentName,
				moduleScript:GetFullName()
			))
			continue
		end
	end
end

return function(plugin, saveState)
	plugin:activate(false)

	local reloadButton = plugin:createButton({
		icon = "",
		active = false,
		tooltip = "Reload the plugin",
		toolbar = plugin:createToolbar("Anatta"),
		name = "Reload",
	})

	local reloadConnection = reloadButton.Click:Connect(function()
		reloadButton:SetActive(true)
		wait()
		plugin:reload()
		reloadButton:SetActive(false)
	end)

	local anatta = Anatta.new(PluginComponents)

	for _, moduleScript in ipairs(CollectionService:GetTagged(DEFINITION_MODULE_TAG_NAME)) do
		loadDefinitions(moduleScript, anatta, plugin)
	end

	anatta:loadSystem(Systems.Entity)

	if saveState then
		anatta.registry:load(saveState)

		anatta.registry:each(function(entity)
			anatta.registry:tryRemove(entity, ".anattaValidationListener")
		end)
	else
		local success, result = Anatta.Dom.tryFromDom(anatta.registry)

		if not success then
			warn(result)
		else
			for _, instance in ipairs(CollectionService:GetTagged(".anattaInstance")) do
				local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

				if anatta.registry:valid(entity) then
					anatta.registry:add(entity, ".anattaInstance", instance)
				end
			end
		end
	end

	plugin:beforeUnload(function()
		plugin:deactivate()
		anatta:unloadAllSystems()
		reloadConnection:Disconnect()

		return anatta.registry
	end)
end

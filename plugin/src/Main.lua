local CollectionService = game:GetService("CollectionService")

local Anatta = require(script.Parent.Parent.Anatta)
local PluginComponents = require(script.Parent.PluginComponents)
local Constants = require(script.Parent.Constants)
local Systems = script.Parent.Systems
local t = Anatta.t

local DEFINITION_MODULE_TAG_NAME = Constants.DefinitionModuleTagName
local PENDING_VALIDATION = Constants.PendingValidation

local function loadDefinitions(moduleScript, anatta)
	if not moduleScript:IsA("ModuleScript") then
		warn(("Components definition instance %s must be a ModuleScript"):format(moduleScript:GetFullName()))
		return
	end

	local componentDefinitions = require(moduleScript)

	for componentName, typeDefinition in pairs(componentDefinitions) do
		if not anatta.registry:hasDefined(componentName) then
			local pendingValidation = PENDING_VALIDATION:format(componentName)

			anatta.registry:define(componentName, typeDefinition)
			anatta:loadSystem(Systems.Generic.Component, componentName, pendingValidation)

			anatta.registry:define(pendingValidation, t.none)
			anatta:loadSystem(Systems.Generic.AttributeValidator, componentName, pendingValidation)
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
	local anatta = Anatta.new(PluginComponents)

	for _, moduleScript in ipairs(CollectionService:GetTagged(DEFINITION_MODULE_TAG_NAME)) do
		loadDefinitions(moduleScript, anatta)
	end

	anatta:loadSystem(Systems.ListenToAttributes)
	anatta:loadSystem(Systems.ForceEntityAttribute)

	if saveState then
		anatta.registry:tryLoad(saveState)
	end

	local reloadButton = plugin:createButton({
		icon = "",
		active = false,
		tooltip = "Reload the plugin",
		toolbar = plugin:createToolbar("Anatta"),
		name = "Reload",
	})

	local reloadConnection = reloadButton.Click:Connect(function()
		plugin:reload()
		reloadButton:SetActive(false)
	end)

	plugin:beforeUnload(function()
		anatta:unloadAllSystems()
		reloadConnection:Disconnect()

		return anatta.registry
	end)
end

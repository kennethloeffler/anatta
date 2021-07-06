local CollectionService = game:GetService("CollectionService")

local Anatta = require(script.Parent.Parent.Anatta)
local PluginComponents = require(script.Parent.PluginComponents)
local Constants = require(script.Parent.Constants)
local Systems = script.Parent.Systems

local DEFINITION_MODULE_TAG_NAME = Constants.DefinitionModuleTagName

local function loadDefinitions(moduleScript, anatta)
	if not moduleScript:IsA("ModuleScript") then
		warn(("Components definition instance %s must be a ModuleScript"):format(moduleScript:GetFullName()))
		return
	end

	local componentDefinitions = require(moduleScript)

	for componentName, typeDefinition in pairs(componentDefinitions) do
		if not anatta.registry:hasDefined(componentName) then
			anatta.registry:define(componentName, typeDefinition)
			anatta:loadSystem(Systems.Generic.ValidationListener, componentName)
			anatta:loadSystem(Systems.Generic.Component, componentName)
		else
			warn(("Found duplicate component name %s in %s; skipping"):format(
				componentName,
				moduleScript:GetFullName()
			))
			continue
		end
	end
end

return function(plugin)
	local anatta = Anatta.new(PluginComponents)

	for _, moduleScript in ipairs(CollectionService:GetTagged(DEFINITION_MODULE_TAG_NAME)) do
		loadDefinitions(moduleScript, anatta)
	end

	anatta:loadSystem(Systems.CheckSelectedAttributes)
	anatta:loadSystem(Systems.ForceEntityAttribute)

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
	end)
end

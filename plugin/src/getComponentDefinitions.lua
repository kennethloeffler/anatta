local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Constants)

local DEFINITION_MODULE_TAG_NAME = Constants.DefinitionModuleTagName

return function()
	local definitionModules = CollectionService:GetTagged(DEFINITION_MODULE_TAG_NAME)
	local allDefinitions = {}

	for _, moduleScript in ipairs(definitionModules) do
		local componentDefinitions = require(moduleScript)

		for componentName, componentDefinition in pairs(componentDefinitions) do
			if allDefinitions[componentName] ~= nil then
				warn(("Found duplicate component name %s in %s; skipping"):format(
					componentName,
					moduleScript:GetFullName()
				))
			else
				allDefinitions[componentName] = componentDefinition
			end
		end
	end

	return allDefinitions
end

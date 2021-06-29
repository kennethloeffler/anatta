local CollectionService = game:GetService("CollectionService")

local MODULE_TAG_NAME = "AnattaPluginComponents"

return function()
	local definitionModules = CollectionService:GetTagged(MODULE_TAG_NAME)
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

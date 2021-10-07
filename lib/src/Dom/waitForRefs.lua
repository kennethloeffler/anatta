local Constants = require(script.Parent.Parent.Core.Constants)

local INSTANCE_REF_FOLDER = Constants.InstanceRefFolder

local function waitForRefs(instance, attributeName, typeDefinition, objectValues, refFolder)
	local _, concreteType = typeDefinition:tryGetConcreteType()
	refFolder = refFolder or instance:WaitForChild(INSTANCE_REF_FOLDER)

	objectValues = objectValues or {}

	if typeof(concreteType) == "table" then
		for field in pairs(concreteType) do
			local fieldAttributeName = ("%s_%s"):format(attributeName, field)
			local fieldTypeDefinition = typeDefinition.typeParams[1][field]

			task.defer(
				waitForRefs,
				instance,
				fieldAttributeName,
				fieldTypeDefinition,
				objectValues,
				refFolder
			)
		end
	elseif concreteType == "instanceOf" or concreteType == "instanceIsA" then
		local objectValue = refFolder:WaitForChild(attributeName)

		if objectValue.Value == nil then
			objectValue.Changed:Wait()
		end

		table.insert(objectValues, objectValue)
	end

	return objectValues
end

return waitForRefs

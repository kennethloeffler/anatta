local Constants = require(script.Parent.Parent.Core.Constants)

local INSTANCE_REF_FOLDER = Constants.InstanceRefFolder

local function waitForRefs(instance, attributeName, typeDefinition, objectValues, refFolder)
	if not typeDefinition._containsRefs then
		return {}
	end

	local _, concreteType = typeDefinition:tryGetConcreteType()

	refFolder = refFolder or instance:WaitForChild(INSTANCE_REF_FOLDER)

	objectValues = objectValues or {}

	local typeParams

	if typeDefinition.typeName == "strictArray" then
		typeParams = typeDefinition.typeParams
	else
		typeParams = typeDefinition.typeParams[1]
	end

	if typeof(concreteType) == "table" then
		for field in pairs(concreteType) do
			local fieldAttributeName = ("%s_%s"):format(attributeName, field)
			local fieldTypeDefinition = typeParams[field]

			waitForRefs(instance, fieldAttributeName, fieldTypeDefinition, objectValues, refFolder)
		end
	elseif
		concreteType == "Instance"
		or concreteType == "instanceIsA"
		or concreteType == "instanceOf"
		or concreteType == "instance"
	then
		local objectValue = refFolder:WaitForChild(attributeName)

		if objectValue.Value == nil then
			objectValue.Changed:Wait()
		end

		table.insert(objectValues, objectValue)
	end

	return objectValues
end

return waitForRefs

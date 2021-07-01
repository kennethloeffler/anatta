local tryToAttribute = require(script.Parent.tryToAttribute)

return function(instance, componentName, typeDefinition)
	local attributeMap = tryToAttribute(componentName, typeDefinition)

	for attributeName, defaultValue in pairs(attributeMap) do
		local value = instance:GetAttribute(attributeName)

		if value == nil then
			attributeMap[attributeName] = value
		else
			instance:SetAttribute(attributeName, defaultValue)
			warn(('Attribute "%s" is missing from instance %s'):format(attributeName, instance:GetFullName()))
		end
	end
end

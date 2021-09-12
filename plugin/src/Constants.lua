local Constants = require(script.Parent.Parent.Anatta.Library.Core.Constants)

local privatePrefix = ".anatta"

return {
	EntityAttributeName = Constants.EntityAttributeName,
	SharedInstanceTagName = Constants.SharedInstanceTagName,
	DefinitionModuleTagName = "AnattaComponentDefinitions",
	PluginPrivateComponentPrefix = privatePrefix,
	PendingValidation = privatePrefix .. "Pending%s",
	SecondsBeforeDestruction = 200,
}

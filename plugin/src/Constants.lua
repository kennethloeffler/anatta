local Constants = require(script.Parent.Parent.Anatta.Library.Core.Constants)

local privatePrefix = "__anattaPlugin"

return {
	EntityAttributeName = Constants.EntityAttributeName,
	DefinitionModuleTagName = "AnattaComponentDefinitions",
	PluginPrivateComponentPrefix = privatePrefix,
	PendingValidation = privatePrefix .. "Pending%s",
}

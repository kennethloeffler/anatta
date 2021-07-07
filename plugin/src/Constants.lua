local privatePrefix = "__anattaPlugin"

return {
	EntityAttributeName = "__entityId",
	DefinitionModuleTagName = "AnattaComponentDefinitions",
	PluginPrivateComponentPrefix = privatePrefix,
	PendingValidation = privatePrefix .. "Pending%s",
}

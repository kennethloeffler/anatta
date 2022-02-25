--[=[
	@class Dom

	`Dom` is a utility module used to convert components to and from attributes and
	`CollectionService` tags on `Instance`s.
]=]

--[=[
	@function tryFromDom
	@within Dom

	@error "Registry must be empty" -- Only an empty Registry can load from the entire Dom.

	@param registry Registry

	Attempts to load entity-component data from attributes and tags existing on all Roblox
	`Instance`s in the `DataModel` into an empty [`Registry`](/api/Registry).

	Components defined on the given [`Registry`](/api/Registry) determine what tag names are
	used to find `Instance`s to convert.

	:::info
	Encountering an `Instance` that fails attribute validation is a soft error. Such an
	`Instance` is skipped and the reason for the failure is logged. Consumers with more
	granular requirements should use [`tryFromAttributes`](#tryFromAttributes) instead.
]=]
local tryFromDom = require(script.tryFromDom)

--[=[
	@function tryFromAttributes
	@within Dom
	@param instance Instance
	@param componentDefinition ComponentDefinition
	@return boolean, number, any

	Attempts to convert the attributes of a given `Instance` into an entity and a
	component of the given
	[`ComponentDefinition`](/api/Anatta#ComponentDefinition). Returns a success value
	followed by the entity and the converted component (if successful) or an error message
	(if unsuccessful).

]=]
local tryFromAttributes = require(script.tryFromAttributes)

--[=[
	@function tryFromTagged
	@within Dom
	@param pool Pool

	Attempts to convert attributes on all the `Instance`s with the `CollectionService` tag
	matching the pool's component name into entities and components.

	:::info
	Encountering an `Instance` that fails attribute validation is a soft error. Such an
	`Instance` is skipped and the reason for the failure is logged. Consumers with more
	granular requirements should use [`tryFromAttributes`](#tryFromAttributes) instead.
]=]
local tryFromTagged = require(script.tryFromTagged)

--[=[
	@function tryToAttributes
	@within Dom
	@param instance Instance
	@param entity number
	@param componentDefinition ComponentDefinition
	@return boolean, {[string]: any]}

	Takes an `Instance`, an entity, a
	[`ComponentDefinition`](/api/Anatta#ComponentDefinition), and a component and attempts
	to convert the component into a dictionary that can be used to set attributes on the
	`Instance`. The keys of the returned dictionary are the names of the requested
	attributes, while the values correspond to the entity and the value(s) of the
	component.

	Returns a success value followed by the attribute dictionary (if successful) or an
	error message (if unsuccessful).

	:::info
	This function has side effects when components contain `Instance` references. When
	this is the case, a `Folder` is created under the given `Instance` and an
	`ObjectValue` under that `Folder` for each `Instance` reference.
]=]
local tryToAttributes = require(script.tryToAttributes)

--[=[
	@function waitForRefs
	@within Dom
	@private
	@yields
]=]
local waitForRefs = require(script.waitForRefs)

return {
	tryFromAttributes = tryFromAttributes,
	tryFromDom = tryFromDom,
	tryFromTagged = tryFromTagged,
	tryToAttributes = tryToAttributes,
	waitForRefs = waitForRefs,
}

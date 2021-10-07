--[=[
	@class Dom

	Utility module to convert components to and from attributes and `CollectionService`
	tags on `Instance`s.
]=]

--[=[
	@function tryFromDom
	@within Dom

	@error "Registry must be empty" -- Only an empty Registry can load from the entire Dom.

	@param registry Registry

	Attempts to load all available entity-component data from attributes and tags on
	Roblox `Instance`s into an empty [`Registry`](Registry).

	Components defined on the given [`Registry`](Registry) determine what tags names
	are used to find `Instance`s to convert.

	:::info
	Encountering an `Instance` that fails attribute validation is a soft error. Such an
	`Instance` is skipped and the reason for the failure is logged. Consumers with more
	granular requirements should use [`tryFromAttribute`](#tryFromAttribute) instead.
]=]
local tryFromDom = require(script.tryFromDom)

--[=[
	@function tryFromAttribute
	@within Dom
	@param instance Instance
	@param componentDefinition ComponentDefinition
	@return boolean, any

	Attempts to convert the attributes of a given `Instance` into a component of the given
	type. Returns a success value followed by the converted component (if successful) or
	an error message (if unsuccessful).
]=]
local tryFromAttribute = require(script.tryFromAttribute)

--[=[
	@function tryFromTag
	@within Dom
	@param pool Pool

	Attempts to convert attributes on all the `Instance`s with the `CollectionService` tag
	matching the pool's component name into entities and components.

	:::info
	Encountering an `Instance` that fails attribute validation is a soft error. Such an
	`Instance` is skipped and the reason for the failure is logged. Consumers with more
	granular requirements should use [`tryFromAttribute`](#tryFromAttribute) instead.
]=]
local tryFromTag = require(script.tryFromTag)

--[=[
	@function tryToAttribute
	@within Dom
	@param instance Instance
	@param component any
	@param componentDefinition ComponentDefinition
	@return boolean, {[string]: any]}

	Attempts to convert the given component into an attribute dictionary. The keys are the
	names of the requested attributes, while the values correspond to the value of the
	component.

	Returns a success value followed by the attribute dictionary (if successful) or an
	error message (if unsuccessful).

	:::info
	This function has side effects when components contain `Instance` references. When
	this is the case, a `Folder` is created under the given `Instance` and an
	`ObjectValue` under that `Folder` for each `Instance` reference.
]=]
local tryToAttribute = require(script.tryToAttribute)

--[=[
	@function waitForRefs
	@within Dom
	@yields
]=]
local waitForRefs = require(script.waitForRefs)

return {
	tryFromAttribute = tryFromAttribute,
	tryFromDom = tryFromDom,
	tryFromTag = tryFromTag,
	tryToAttribute = tryToAttribute,
	waitForRefs = waitForRefs,
}

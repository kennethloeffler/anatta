--[=[
	@class Dom

	Provides functionality to convert components to and from and attributes and tags on
	Roblox `Instance`s.
]=]

--[=[
	@function tryFromDom
	@within Dom
	@param registry Registry

	Tries to load any and all entity component data from attributes and tags on Roblox
	`Instance`s into an empty [`Registry`](Registry). Throws if the registry is not
	empty. It is not an error for an `Instance` to fail validation; instead, a warning is
	printed.
]=]
local tryFromDom = require(script.tryFromDom)

local tryFromAttribute = require(script.tryFromAttribute)

--[=[
	@function tryFromTag
	@within Dom
	@param pool Pool

	Attempts to convert attributes from `Instance`s tagged with an empty [`Pool`](Pool)'s
	name into entities and components of the correct type.

	Throws if a conversion fails (it's likely that the entire set of attributes is bad in
	this case). It is not a an error for only the entity attribute is invalid; instead, a
	warning is printed.
]=]
local tryFromTag = require(script.tryFromTag)
local tryToAttribute = require(script.tryToAttribute)
local waitForRefs = require(script.waitForRefs)

return {
	tryFromAttribute = tryFromAttribute,
	tryFromDom = tryFromDom,
	tryFromTag = tryFromTag,
	tryToAttribute = tryToAttribute,
	waitForRefs = waitForRefs,
}

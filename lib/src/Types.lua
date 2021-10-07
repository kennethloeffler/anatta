local t = require(script.Parent.Parent.t)

local TypeDefinition = t.strictInterface({
	typeParams = t.table,
	check = t.callback,
	typeName = t.string,
})

--- @interface ComponentDefinition
--- @within Anatta
--- .name string
--- .type TypeDefinition
--- .description string?
--- A named component type with an optional description.
local ComponentDefinition = t.strictInterface({
	description = t.optional(t.string),
	name = t.string,
	type = TypeDefinition,
})

--[=[
	@interface Query
	@within World
	.withAll {string}?
	.withUpdated {string}?
	.withAny {string}?
	.without {string}?

	A `Query` represents a component aggregation to retrieve from a
	[`Registry`](Registry). A `Query` can be finalized by passing it to
	[`World:getReactor`](#getReactor) or [`World:getMapper`](#getMapper).

	Various [`Reactor`](Reactor) and [`Mapper`](Mapper) methods accept callbacks that are
	passed an entity and its components. Such callbacks receive the entity as the first
	argument, followed by the entity's components from `withAll`, then the components from
	`withUpdated`, and finally the components from `withAny`.

	### `Query.withAll`
	An entity must have all of the components specified in `withAll` to appear.

	### `Query.withUpdated`
	An entity must have an updated copy of all the components specified in `withUpdated`
	to appear.

	### `Query.withAny`
	An entity may have any or none of the components specified in `withAny` and still
	appear.

	### `Query.without`
	An entity must not have any of the components specified in `without` to appear.
]=]
local Query = t.strictInterface({
	withAll = t.optional(t.array(t.string)),
	withUpdated = t.optional(t.array(t.string)),
	withAny = t.optional(t.array(t.string)),
	without = t.optional(t.array(t.string)),
})

return {
	ComponentDefinition = ComponentDefinition,
	Query = Query,
	TypeDefinition = TypeDefinition,
}

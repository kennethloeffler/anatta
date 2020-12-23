return function()
	local Constants = require(script.Parent.Parent.Core.Constants)
	local Registry = require(script.Parent.Registry)
	local t = require(script.Parent.Parent.Core.TypeDefinition)

	local ENTITYID_MASK = Constants.ENTITYID_MASK
	local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
	local NULL_ENTITYID = Constants.NULL_ENTITYID

	local function makeEntities(registry, num)
		local entities = table.create(num)

		for i = 1, num do
			entities[i] = registry:create()
		end

		return entities
	end

	beforeEach(function(context)
		local registry = Registry.new()

		registry:define("interface", t.interface { instance = t.Instance })
		registry:define("instance", t.Instance)
		registry:define("number", t.number)

		context.registry = registry
	end)

	describe("new", function()
		it("should construct a new empty Registry", function()
			local registry = Registry.new()

			expect(getmetatable(registry)).to.equal(Registry)
			expect(registry._size).to.equal(0)
			expect(registry._nextRecyclable).to.equal(NULL_ENTITYID)
			expect(registry._entities).to.be.a("table")
			expect(next(registry._entities)).to.equal(nil)
			expect(registry._pools).to.be.a("table")
			expect(next(registry._pools)).to.equal(nil)
		end)
	end)

	describe("define", function()
		it("should define a new component type", function()
			local registry = Registry.new()
			local typeDef = t.table

			registry:define("Test", typeDef)

			expect(registry._pools.Test).to.be.ok()
			expect(registry._pools.Test.typeDef).to.equal(typeDef)
			expect(registry._pools.Test.name).to.equal("Test")
		end)

		it("should error if the name is already in use", function()
			local registry = Registry.new()

			registry:define("Test", t.none)

			expect(function()
				registry:define("Test", t.none)
			end).to.throw()
		end)

		it("should attach removal signal listeners to automatically destroy instance types/members", function(context)
			local registry = context.registry
			local instancePool = registry._pools.instance
			local interfacePool = registry._pools.interface

			local entity = registry:create()
			local instance = instancePool:insert(entity, Instance.new("Part"))

			instancePool.onRemove:dispatch(entity, instance)

			expect(function()
				instance.Parent = workspace
			end).to.throw()

			local interface = interfacePool:insert(entity, { instance = Instance.new("Script") })

			interfacePool.onRemove:dispatch(entity, interface)

			expect(function()
				interface.instance.Parent = workspace
			end).to.throw()
		end)
	end)

	describe("create", function()
		it("should return a valid entity identifier", function(context)
			for _, entity in ipairs(makeEntities(context.registry, 100)) do
				expect(context.registry:valid(entity)).to.equal(true)
			end
		end)

		it("should increment size when there are no recyclable ids", function(context)
			context.registry:create()
			expect(context.registry._size).to.equal(1)
		end)

		it("should recycle the ids of destroyed entities", function(context)
			local registry = context.registry
			local num = 50
			local destroyedIds = table.create(num)

			for i, entity in ipairs(makeEntities(registry, 100)) do
				if i % 2 == 0 then
					-- fill the table in reverse order so it will be in the same
					-- order that the ids will be recycled in
					destroyedIds[num] = bit32.band(entity, ENTITYID_MASK)
					registry:destroy(entity)
					num -= 1

					expect(registry._nextRecyclable).to.equal(bit32.band(entity, ENTITYID_MASK))
				end
			end

			for i, destroyedId in ipairs(destroyedIds) do
				local nextRecyclable = destroyedIds[i + 1] and destroyedIds[i + 1] or NULL_ENTITYID

				expect(bit32.band(registry:create(), ENTITYID_MASK)).to.equal(destroyedId)
				expect(registry._nextRecyclable).to.equal(nextRecyclable)

				if i < 50 then
					expect(bit32.band(registry._entities[nextRecyclable], ENTITYID_MASK))
						.to.equal(destroyedIds[i + 2] or NULL_ENTITYID)
				end
			end
		end)
	end)

	describe("createFrom", function()
		it("should return an entity identifier equal to hint when hint's entity id is not in use", function(context)
			expect(context.registry:createFrom(0xDEADBEEF)).to.equal(0xDEADBEEF)
		end)

		it("should return an entity identifier equal to hint when hint's entity id has been recycled", function(context)
			local registry = context.registry
			local entity = makeEntities(registry, 100)[50]

			registry:destroy(entity)

			for _ = 1, 100 do
				registry:destroy(registry:create())
			end

			expect(registry:createFrom(entity)).to.equal(entity)
		end)

		it("should properly remove an entity from the stack of recyclable entities", function(context)
			local registry = context.registry

			makeEntities(registry, 100)

			registry:destroy(2)
			registry:destroy(4)
			registry:destroy(16)
			registry:destroy(32)
			registry:destroy(64)

			expect(registry:createFrom(16)).to.equal(16)
			expect(registry:createFrom(bit32.bor(64, bit32.lshift(16, ENTITYID_WIDTH))))
				.to.equal(bit32.bor(64, bit32.lshift(16, ENTITYID_WIDTH)))
			expect(registry:createFrom(4)).to.equal(4)

			expect(bit32.band(registry:create(), ENTITYID_MASK)).to.equal(32)
			expect(bit32.band(registry:create(), ENTITYID_MASK)).to.equal(2)
		end)

		it("should return a brand new entity identifier when the entity id is in use", function(context)
			local entity = makeEntities(context.registry, 100)[60]

			expect(context.registry:createFrom(entity)).to.equal(context.registry._size)
		end)
	end)

	describe("destroy", function()
		it("should remove all components that are on the entity", function(context)
			local registry = context.registry
			local numberPool = registry._pools.number
			local instancePool = registry._pools.instance
			local entity = registry:create()

			numberPool:insert(entity, 10)
			instancePool:insert(entity, Instance.new("Hole"))

			registry:destroy(entity)

			expect(numberPool:contains(entity)).to.equal(nil)
			expect(instancePool:contains(entity)).to.equal(nil)
		end)

		it("should increment the entity's version field", function(context)
			local registry = context.registry
			local entity = registry:create()
			local entityId = bit32.band(entity, ENTITYID_MASK)
			local expectedVersion = 123

			registry:destroy(entity)

			for _ = 1, 122 do
				registry:destroy(registry:create())
			end

			expect(bit32.rshift(registry._entities[entityId], ENTITYID_WIDTH)).to.equal(expectedVersion)
		end)

		it("should push the entity's id onto the free list", function(context)
			local registry = context.registry
			local entity = registry:create()
			local entityId = bit32.band(entity, ENTITYID_MASK)

			registry:destroy(entity)

			expect(registry._nextRecyclable).to.equal(entityId)
			expect(bit32.band(registry._entities[entityId], ENTITYID_MASK)).to.equal(NULL_ENTITYID)
		end)

		it("should error when given an invalid entity", function(context)
			expect(function()
				context.registry:destroy(0)
			end).to.throw()
		end)
	end)

	describe("valid", function()
		it("should return true if the entity identifier is valid", function(context)
			local registry = context.registry

			expect(registry:valid(registry:create())).to.equal(true)
		end)

		it("should return false if the entity identifier is not valid", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry:destroy(entity)

			expect(registry:valid(entity)).to.equal(false)
			expect(registry:valid(NULL_ENTITYID)).to.equal(false)
		end)

		it("should error if entity is not a number", function(context)
			expect(function()
				context.registry:valid("entity")
			end).to.throw()
		end)
	end)

	describe("stub", function()
		it("should return true if the entity has no components", function(context)
			expect(context.registry:stub(context.registry:create())).to.equal(true)
		end)

		it("should return false if the entity has any components", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry:add(entity, "number", 10)

			expect(context.registry:stub(entity)).to.equal(false)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:stub(0)
			end).to.throw()
		end)
	end)

	describe("visit", function()
		it("should return all component names managed by the registry", function(context)
			local componentDefs = {}

			for componentDef in pairs(context.registry._pools) do
				componentDefs[componentDef] = componentDef
			end

			context.registry:visit(function(componentDef)
				expect(componentDefs[componentDef]).to.equal(componentDef)
				componentDefs[componentDef] = nil
			end)

			expect(next(componentDefs)).to.equal(nil)
		end)

		it("if passed an entity, should return the component names which it has", function(context)
			local registry = context.registry
			local entity = registry:create()

			local components = {
				number = true,
				instance = true,
			}

			registry._pools.number:insert(entity, 10)
			registry._pools.instance:insert(entity, Instance.new("Hole"))

			registry:visit(function(name)
				expect(components[name]).to.equal(true)
				components[name] = nil
			end, entity)

			expect(next(components)).to.equal(nil)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:visit(function() end, 0)
			end).to.throw()
		end)
	end)

	describe("has", function()
		it("should return false if the entity does not have the components", function(context)
			local registry = context.registry

			expect(registry:has(registry:create(), "instance", "number")).to.equal(false)
		end)

		it("should return true if the entity has the components", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry._pools.instance:insert(entity, Instance.new("Part"))
			registry._pools.number:insert(entity, 10)

			expect(registry:has(entity, "instance", "number")).to.equal(true)
		end)

		it("should error if give an invalid entity", function(context)
			expect(function()
				context.registry:has(0, "number")
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:has(context.registry:create(), "")
			end).to.throw()
		end)
	end)

	describe("any", function()
		it("should return false if the entity does not have any of the components", function(context)
			local registry = context.registry

			expect(registry:any(registry:create(), "instance", "number")).to.equal(false)
		end)

		it("should return true if the entity has any of the components", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry._pools.instance:insert(entity, Instance.new("Part"))
			registry._pools.number:insert(entity, 10)

			expect(registry:any(entity, "number", "instance")).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:any(0, "number")
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:any(context.registry:create(), "")
			end).to.throw()
		end)
	end)

	describe("get", function()
		it("should return the component instance if the entity has the component", function(context)
			local registry = context.registry
			local entity = registry:create()
			local obj = Instance.new("Hole")

			registry._pools.instance:insert(entity, obj)
			expect(registry:get(entity, "instance")).to.equal(obj)
		end)

		it("should error if the entity does not have the component", function(context)
			expect(function()
				context.registry:get(context.registry:create(), "number")
			end).to.throw()
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:get(0, "number")
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:get(context.registry:create(), "")
			end).to.throw()
		end)
	end)

	describe("tryGet", function()
		it("should return nil if the entity does not have the component", function(context)
			local registry = context.registry
			local entity = registry:create()

			expect(registry:tryGet(entity, "number")).to.never.be.ok()
		end)

		it("should return the component instance if the entity has the component", function(context)
			local registry = context.registry
			local entity = registry:create()
			local obj = { instance = Instance.new("Hole") }

			registry._pools.interface:insert(entity, obj)
			expect(registry:tryGet(entity, "interface")).to.equal(obj)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:tryGet(0, "number")
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:tryGet(context.registry:create(), "")
			end).to.throw()
		end)
	end)

	describe("multiGet", function()
		it("should return the specified components on the entity in order", function(context)
			local registry = context.registry
			local entity = registry:create()
			local tab = table.create(2)
			local component1 = { instance = Instance.new("Script") }
			local component2 = 10

			registry._pools.instance:insert(entity, component1)
			registry._pools.number:insert(entity, component2)

			local instance, number = registry:multiGet(entity, tab, "instance", "number")

			expect(instance).to.equal(component1)
			expect(number).to.equal(component2)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:multiGet(0, {}, "number", "instance")
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:multiGet(context.registry:create(), {}, "")
			end).to.throw()
		end)
	end)

	describe("add", function()
		it("should add a new component instance to the entity and return it", function(context)
			local registry = context.registry
			local entity = registry:create()
			local component = Instance.new("Script")
			local obj = registry:add(entity, "instance", component)

			expect(registry._pools.instance:contains(entity)).to.be.ok()
			expect(component).to.equal(obj)
		end)

		it("should dispatch the component pool's insertion signal", function(context)
			local registry = context.registry
			local ranCallback

			registry._pools.instance.onAdd:connect(function()
				ranCallback = true
			end)

			registry:add(registry:create(), "instance", Instance.new("Hole"))
			expect(ranCallback).to.equal(true)
		end)

		it("should return the correct component instance when a recycled entity is used", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry:destroy(entity)
			entity = registry:create()

			expect(registry:add(entity, "instance", Instance.new("Part")))
				.to.equal(registry._pools.instance:get(entity))
		end)

		it("should correctly handle tag components", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry:define("tag", t.none)
			registry:add(entity, "tag")

			expect(registry._pools.tag:contains(entity)).to.be.ok()
			expect(registry._pools.tag:get(entity)).to.equal(nil)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:add(0, "number", 1)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:add(context.registry:create(), "")
			end).to.throw()
		end)
	end)

	describe("tryAdd", function()
		it("should return nil if the component already exists on the entity", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry._pools.number:insert(entity, 100)

			expect(registry:tryAdd(entity, "number", 10)).to.equal(nil)
		end)

		it("should add a new component instance to the entity and return it if the component does not exist on the entity", function(context)
			local registry = context.registry
			local entity = registry:create()
			local component = Instance.new("Hole")
			local obj = registry:tryAdd(entity, "instance", component)

			expect(registry._pools.instance:contains(entity)).to.be.ok()
			expect(component).to.equal(obj)
		end)

		it("should dispatch the component pool's insertment signal", function(context)
			local registry = context.registry
			local ranCallback

			registry._pools.number.onAdd:connect(function()
				ranCallback = true
			end)

			registry:tryAdd(registry:create(), "number", 10)
			expect(ranCallback).to.equal(true)
		end)

		it("should return the correct component instance when a recycled entity is used", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry:destroy(entity)
			entity = registry:create()

			expect(registry:tryAdd(entity, "instance", Instance.new("Hole")))
				.to.equal(registry._pools.instance:get(entity))
		end)

		it("should correctly handle tag components", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry:define("tag", t.none)
			registry:tryAdd(entity, "tag")

			expect(registry._pools.tag:contains(entity)).to.be.ok()
			expect(registry._pools.tag:get(entity)).to.equal(nil)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:tryAdd(0, "number", 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:tryAdd(context.registry:create(), "")
			end).to.throw()
		end)
	end)
	describe("multiAdd", function()
		it("should add all of the specified components to the entity then return the entity", function(context)
			local registry = context.registry
			local component1 = Instance.new("Hole")
			local component2 = { instance = Instance.new("Hole") }
			local component3 = 10
			local pool1 = registry._pools.instance
			local pool2 = registry._pools.interface
			local pool3 = registry._pools.number
			local entity = registry:multiAdd(registry:create(),
				"instance", component1,
				"interface", component2,
				"number", component3)

			expect(pool1:get(entity)).to.equal(component1)
			expect(pool2:get(entity)).to.equal(component2)
			expect(pool3:get(entity)).to.equal(component3)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:multiAdd(0, "number", 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:multiAdd(context.registry:create(), "")
			end).to.throw()
		end)
	end)

	describe("getOrAdd", function()
		it("should add and return the component if the entity doesn't have it", function(context)
			local registry = context.registry
			local entity = registry:create()

			expect(registry:getOrAdd(entity, "number", 10)).to.equal(10)
		end)

		it("should return the component instance if the entity already has it", function(context)
			local registry = context.registry
			local entity = registry:create()
			local obj = registry._pools.instance:insert(entity, Instance.new("Hole"))

			expect(registry:getOrAdd(entity, "instance", Instance.new("Hole"))).to.equal(obj)
		end)

		it("should dispatch the component pool's added signal", function(context)
			local registry =  context.registry
			local ranCallback

			registry._pools.number.onAdd:connect(function()
				ranCallback = true
			end)

			registry:getOrAdd(registry:create(), "number", 10)
			expect(ranCallback).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:getOrAdd(0, "number", 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:getOrAdd(context.registry:create(), "")
			end).to.throw()
		end)
	end)

	describe("replace", function()
		it("should replace an existing component instance with a new one", function(context)
			local registry = context.registry
			local entity = registry:create()
			local obj = Instance.new("Hole")

			registry._pools.instance:insert(entity, Instance.new("Hole"))
			expect(registry:replace(entity, "instance", obj)).to.equal(obj)
			expect(registry._pools.instance:get(entity)).to.equal(obj)
		end)

		it("should dispatch the component pool's update signal", function(context)
			local registry = context.registry
			local entity = registry:create()
			local ranCallback

			registry._pools.number.onUpdate:connect(function()
				ranCallback = true
			end)

			registry._pools.number:insert(entity, 10)
			registry:replace(entity, "number", 11)

			expect(ranCallback).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:replace(0, "number", 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:replace(context.registry:create(), "")
			end).to.throw()
		end)

		it("should error if the entity does not have the component", function(context)
			expect(function()
				context.registry:replace(context.registry:create(), "number", 0)
			end).to.throw()
		end)
	end)

	describe("addOrReplace", function()
		it("should add the component if it does not exist on the entity", function(context)
			local registry = context.registry
			local entity = registry:create()
			local added = 10

			expect(registry:addOrReplace(entity, "number", added)).to.equal(added)
			expect(registry._pools.number:get(entity)).to.equal(added)
		end)

		it("should dispatch the component pool's added signal", function(context)
			local registry = context.registry
			local ranAddCallback

			registry._pools.instance.onAdd:connect(function()
				ranAddCallback = true
			end)

			registry:addOrReplace(registry:create(), "instance", Instance.new("Hole"))
			expect(ranAddCallback).to.equal(true)
		end)

		it("should replace the component if it already exists on the entity", function(context)
			local registry = context.registry
			local entity = registry:create()
			local replaced = 12

			expect(registry:addOrReplace(entity, "number", replaced)).to.equal(replaced)
			expect(registry._pools.number:get(entity)).to.equal(replaced)
		end)

		it("should dispatch the component pool's replacement signal", function(context)
			local registry = context.registry
			local entity = registry:create()
			local ranReplaceCallback = false

			registry._pools.instance.onUpdate:connect(function()
				ranReplaceCallback = true
			end)

			registry._pools.instance:insert(entity, Instance.new("Hole"))
			registry:addOrReplace(entity, "instance", Instance.new("Hole"))

			expect(ranReplaceCallback).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:addOrReplace(0, "number", 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:addOrReplace(context.registry:create(), "")
			end).to.throw()
		end)
	end)

	describe("remove", function()
		it("should remove a component that has been added to the entity", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry._pools.number:insert(entity, 12)
			registry:remove(entity, "number")

			expect(registry._pools.number:contains(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local registry = context.registry
			local entity = registry:create()
			local ranCallback

			registry._pools.number.onRemove:connect(function()
				ranCallback = true
			end)

			registry._pools.number:insert(entity, 100)
			registry:remove(entity, "number")

			expect(ranCallback).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:remove(0, "number", 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:remove(context.registry:create(), "")
			end).to.throw()
		end)

		it("should error if the entity does not have the component", function(context)
			expect(function()
				context.registry:remove(context.registry:create(), "number")
			end).to.throw()
		end)
	end)

	describe("multiRemove", function()
		it("should remove all of the specified components from the entity and dispatch each components' removal signals", function(context)
			local registry = context.registry
			local entity = registry:create()

			local component1 = registry._pools.number:insert(entity, 10)
			local component2 = registry._pools.instance:insert(entity, Instance.new("Hole"))
			local component3 = registry._pools.interface:insert(entity, { instance = Instance.new("Part") })
			local component1ok = false
			local component2ok = false
			local component3ok = false

			registry._pools.number.onRemove:connect(function(e, component)
				expect(e).to.equal(entity)
				expect(component).to.equal(component1)
				component1ok = true
			end)

			registry._pools.instance.onRemove:connect(function(e, component)
				expect(e).to.equal(entity)
				expect(component).to.equal(component2)
				component2ok = true
			end)

			registry._pools.interface.onRemove:connect(function(e, component)
				expect(e).to.equal(entity)
				expect(component).to.equal(component3)
				component3ok = true
			end)

			registry:multiRemove(entity, "number", "instance", "interface")

			expect(component1ok).to.equal(true)
			expect(component2ok).to.equal(true)
			expect(component3ok).to.equal(true)
			expect(registry._pools.number:contains(entity)).to.equal(nil)
			expect(registry._pools.instance:contains(entity)).to.equal(nil)
			expect(registry._pools.interface:contains(entity)).to.equal(nil)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:multiRemove(0, "number")
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:multiRemove(context.registry:create(), "")
			end).to.throw()
		end)

		it("should error if the entity does not have a component", function(context)
			expect(function()
				context.registry:multiRemove(context.registry:create(), "number")
			end).to.throw()
		end)

	end)

	describe("tryRemove", function()
		it("should return false if the component does not exist on the entity", function(context)
			local registry = context.registry
			local entity = registry:create()

			expect(registry:tryRemove(entity, "instance")).to.equal(false)
		end)

		it("should remove a component if it exists on the entity and return true", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry._pools.number:insert(entity, 10)
			expect(registry:tryRemove(entity, "number")).to.equal(true)

			expect(registry._pools.number:contains(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local registry = context.registry
			local entity = registry:create()
			local ranCallback

			registry._pools.number.onRemove:connect(function()
				ranCallback = true
			end)

			registry._pools.number:insert(entity, 10)
			registry:tryRemove(entity, "number")

			expect(ranCallback).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:tryRemove(0, "number")
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:tryRemove(context.registry:create(), "")
			end).to.throw()
		end)
	end)

	describe("each", function()
		it("should iterate over all non-destroyed entities", function(context)
			local registry = context.registry
			local entities = {}

			for i = 1, 128 do
				entities[i] = registry:create()
			end

			for i, entity in ipairs(entities) do
				if i % 16 == 0 then
					registry:destroy(entity)
				end
			end

			-- make some entities which will have incremented versions
			registry:create()
			registry:create()
			registry:create()

			registry:each(function(entity)
				local id = bit32.band(entity, ENTITYID_MASK)

				expect(id).to.equal(bit32.band(registry._entities[id], ENTITYID_MASK))
			end)
		end)
	end)

	describe("numEntities", function()
		it("should return the number of non-destroyed entities currently in the registry", function(context)
			local registry = context.registry
			local numEntities = 128
			local entities = table.create(numEntities)

			for i = 1, numEntities do
				entities[i] = registry:create()
			end

			for i, entity in ipairs(entities) do
				if i % 16 == 0 then
					numEntities = numEntities - 1
					registry:destroy(entity)
				end
			end

			expect(registry:numEntities()).to.equal(numEntities)
		end)
	end)

	describe("raw", function()
		it("should return the pool's internal structures", function(context)
			local registry = context.registry
			local dense, objects = registry:raw("instance")
			local pool = registry._pools.instance

			expect(dense).to.equal(pool.dense)
			expect(objects).to.equal(pool.objects)
		end)
	end)

	describe("count", function()
		it("should return the number of elements in the pool", function(context)
			local registry = context.registry
			local pool = registry._pools.number

			for i = 1, 10 do
				pool:insert(i, 0)
			end

			expect(registry:count("number")).to.equal(10)
		end)
	end)

	describe("getPools", function()
		it("should return the pools for the specified component types", function(context)
			local registry = context.registry
			local pools = registry:getPools("number", "instance")

			expect(pools[1]).to.equal(registry._pools.number)
			expect(pools[2]).to.equal(registry._pools.instance)
		end)
	end)
end

return function()
	local Constants = require(script.Parent.Parent.Core.Constants)
	local Registry = require(script.Parent.Registry)
	local t = require(script.Parent.Parent.Core.Type)

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
		context.registry = Registry.new({
			interface = t.interface({ instance = t.Instance }),
			instance = t.Instance,
			number = t.number,
			tag = t.none,
		})
	end)

	describe("new", function()
		it("should construct a new empty Registry", function()
			local registry = Registry.new({})

			expect(getmetatable(registry)).to.equal(Registry)
			expect(registry._size).to.equal(0)
			expect(registry._nextRecyclableEntityId).to.equal(NULL_ENTITYID)
			expect(registry._entities).to.be.a("table")
			expect(next(registry._entities)).to.equal(nil)
			expect(registry._pools).to.be.a("table")
			expect(next(registry._pools)).to.equal(nil)
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
			local maxDestroyed = 50
			local destroyed = table.create(maxDestroyed)

			for i, entity in ipairs(makeEntities(registry, 100)) do
				if i % 2 == 0 then
					-- We fill the table in reverse order because the free list is fifo
					destroyed[maxDestroyed] = Registry.getId(entity)
					registry:destroy(entity)
					maxDestroyed -= 1

					expect(registry._nextRecyclableEntityId).to.equal(Registry.getId(entity))
				end
			end

			for i, destroyedEntity in ipairs(destroyed) do
				local nextRecyclableEntityId = destroyed[i + 1] and destroyed[i + 1] or NULL_ENTITYID

				expect(Registry.getId(registry:create())).to.equal(destroyedEntity)
				expect(registry._nextRecyclableEntityId).to.equal(nextRecyclableEntityId)

				if nextRecyclableEntityId ~= NULL_ENTITYID then
					-- If we are not at the end of the free list, then the recyclable
					-- id's element in ._entities should point to the next recyclable
					-- id.
					expect(Registry.getId(registry._entities[nextRecyclableEntityId])).to.equal(
						destroyed[i + 2] or NULL_ENTITYID
					)
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

		it("should remove entities from the stack of recyclable entities", function(context)
			local registry = context.registry

			makeEntities(registry, 100)

			-- We need to make sure createFrom correctly removes ids from the middle of
			-- the free list. First we populate it with some ids:
			-- 64, 32, 16, 4, 2
			registry:destroy(2)
			registry:destroy(4)
			registry:destroy(16)
			registry:destroy(32)
			registry:destroy(64)

			-- Next we create entity 16, which is in the middle of the free
			-- list. After this operation, the free list should look like this:
			-- 64, 32, 4, 2
			local e16 = registry:createFrom(16)
			expect(Registry.getId(e16)).to.equal(16)
			expect(Registry.getVersion(e16)).to.equal(0)

			-- Now we create entity 64 with an arbitrary version. The free list should
			-- now look like this:
			-- 32, 4, 2
			local version = 16
			local entity = registry:createFrom(bit32.bor(64, bit32.lshift(version, ENTITYID_WIDTH)))
			expect(Registry.getId(entity)).to.equal(64)
			expect(Registry.getVersion(entity)).to.equal(16)

			-- ...
			-- 32, 2
			local e4 = registry:createFrom(4)
			expect(Registry.getId(e4)).to.equal(4)
			expect(Registry.getVersion(e4)).to.equal(0)

			-- Finally we do a couple normal :creates to make sure the free list is in
			-- the proper state
			local e32 = registry:create()
			expect(Registry.getId(e32)).to.equal(32)
			expect(Registry.getVersion(e32)).to.equal(1)

			local e2 = registry:create()
			expect(Registry.getId(e2)).to.equal(2)
			expect(Registry.getVersion(e2)).to.equal(1)
		end)

		it("should return a new entity identifier when the entity id is in use", function(context)
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

			expect(numberPool:getIndex(entity)).to.equal(nil)
			expect(instancePool:getIndex(entity)).to.equal(nil)
		end)

		it("should increment the entity's version field", function(context)
			local registry = context.registry
			local entity = registry:create()
			local entityId = Registry.getId(entity)
			local expectedVersion = 123

			registry:destroy(entity)

			for _ = 1, 122 do
				registry:destroy(registry:create())
			end

			expect(Registry.getVersion(registry._entities[entityId])).to.equal(expectedVersion)
		end)

		it("should push the entity's id onto the free list", function(context)
			local registry = context.registry
			local entity = registry:create()
			local entityId = Registry.getId(entity)

			registry:destroy(entity)

			expect(registry._nextRecyclableEntityId).to.equal(entityId)
			expect(Registry.getId(registry._entities[entityId])).to.equal(NULL_ENTITYID)
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
				context.registry:visit(function()
				end, 0)
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

		it("should return nil if the entity does not have the component", function(context)
			local registry = context.registry
			expect(registry:get(registry:create(), "number")).to.equal(nil)
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

	describe("multiGet", function()
		it("should return the specified components on the entity in order", function(context)
			local registry = context.registry
			local entity = registry:create()
			local component1 = { instance = Instance.new("Script") }
			local component2 = 10

			registry._pools.instance:insert(entity, component1)
			registry._pools.number:insert(entity, component2)

			local instance, number = registry:multiGet(entity, {}, "instance", "number")

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

			expect(registry._pools.instance:getIndex(entity)).to.be.ok()
			expect(component).to.equal(obj)
		end)

		it("should dispatch the component pool's insertion signal", function(context)
			local registry = context.registry
			local ranCallback

			registry._pools.instance.added:connect(function()
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

			expect(registry:add(entity, "instance", Instance.new("Part"))).to.equal(registry._pools.instance:get(entity))
		end)

		it("should correctly handle tag components", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry:add(entity, "tag")

			expect(registry._pools.tag:getIndex(entity)).to.be.ok()
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

		it(
			"should add a new component instance to the entity and return it if the component does not exist on the entity",
			function(context)
				local registry = context.registry
				local entity = registry:create()
				local component = Instance.new("Hole")
				local obj = registry:tryAdd(entity, "instance", component)

				expect(registry._pools.instance:getIndex(entity)).to.be.ok()
				expect(component).to.equal(obj)
			end
		)

		it("should dispatch the component pool's insertment signal", function(context)
			local registry = context.registry
			local ranCallback

			registry._pools.number.added:connect(function()
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

			expect(registry:tryAdd(entity, "instance", Instance.new("Hole"))).to.equal(registry._pools.instance:get(entity))
		end)

		it("should correctly handle tag components", function(context)
			local registry = context.registry
			local entity = registry:create()

			registry:tryAdd(entity, "tag")

			expect(registry._pools.tag:getIndex(entity)).to.be.ok()
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
			local entity = registry:multiAdd(registry:create(), {
				instance = component1,
				interface = component2,
				number = component3,
			})

			expect(pool1:get(entity)).to.equal(component1)
			expect(pool2:get(entity)).to.equal(component2)
			expect(pool3:get(entity)).to.equal(component3)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:multiAdd(0, { number = 0 })
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:multiAdd(context.registry:create(), { dkfjdkfj = 0 })
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
			local registry = context.registry
			local ranCallback

			registry._pools.number.added:connect(function()
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
			local new = 11
			local ranCallback

			registry._pools.number.updated:connect(function(_, newComponent)
				expect(newComponent).to.equal(new)
				ranCallback = true
			end)

			local entity = registry:create()
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

			registry._pools.instance.added:connect(function()
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

		it("should dispatch the component pool's replaced signal", function(context)
			local registry = context.registry
			local entity = registry:create()
			local ranReplaceCallback = false

			registry._pools.instance.updated:connect(function()
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

			expect(registry._pools.number:getIndex(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local registry = context.registry
			local entity = registry:create()
			local ranCallback

			registry._pools.number.removed:connect(function()
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
		it(
			"should remove all of the specified components from the entity and dispatch each components' removal signals",
			function(context)
				local registry = context.registry
				local entity = registry:create()

				local component1 = registry._pools.number:insert(entity, 10)
				local component2 = registry._pools.instance:insert(entity, Instance.new("Hole"))
				local component3 = registry._pools.interface:insert(entity, { instance = Instance.new("Part") })
				local component1ok = false
				local component2ok = false
				local component3ok = false

				registry._pools.number.removed:connect(function(e, component)
					expect(e).to.equal(entity)
					expect(component).to.equal(component1)
					component1ok = true
				end)

				registry._pools.instance.removed:connect(function(e, component)
					expect(e).to.equal(entity)
					expect(component).to.equal(component2)
					component2ok = true
				end)

				registry._pools.interface.removed:connect(function(e, component)
					expect(e).to.equal(entity)
					expect(component).to.equal(component3)
					component3ok = true
				end)

				registry:multiRemove(entity, "number", "instance", "interface")

				expect(component1ok).to.equal(true)
				expect(component2ok).to.equal(true)
				expect(component3ok).to.equal(true)
				expect(registry._pools.number:getIndex(entity)).to.equal(nil)
				expect(registry._pools.instance:getIndex(entity)).to.equal(nil)
				expect(registry._pools.interface:getIndex(entity)).to.equal(nil)
			end
		)

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

			expect(registry._pools.number:getIndex(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local registry = context.registry
			local entity = registry:create()
			local ranCallback

			registry._pools.number.removed:connect(function()
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
				local entityId = Registry.getId(entity)

				expect(entityId).to.equal(Registry.getId(registry._entities[entityId]))
			end)
		end)
	end)

	describe("countEntities", function()
		it("should return the number of non-destroyed entities currently in the registry", function(context)
			local registry = context.registry
			local count = 128
			local entities = table.create(count)

			for i = 1, count do
				entities[i] = registry:create()
			end

			for i, entity in ipairs(entities) do
				if i % 16 == 0 then
					count = count - 1
					registry:destroy(entity)
				end
			end

			expect(registry:countEntities()).to.equal(count)
		end)
	end)

	describe("raw", function()
		it("should return the pool's .dense and .components fields", function(context)
			local registry = context.registry
			local dense, components = registry:raw("instance")
			local pool = registry._pools.instance

			expect(dense).to.equal(pool.dense)
			expect(components).to.equal(pool.components)
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

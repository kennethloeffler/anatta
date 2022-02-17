return function()
	local Constants = require(script.Parent.Parent.Core.Constants)
	local Registry = require(script.Parent.Registry)
	local T = require(script.Parent.Parent.Core.T)

	local ENTITYID_WIDTH = Constants.EntityIdWidth
	local NULL_ENTITYID = Constants.NullEntityId

	local Component = {
		interface = {
			name = "interface",
			type = T.interface({ instance = T.Instance }),
		},
		instance = {
			name = "instance",
			type = T.Instance,
		},
		number = {
			name = "number",
			type = T.number,
		},
		tag = {
			name = "tag",
			type = T.none,
		},
	}

	local function makeEntities(registry, num)
		local entities = table.create(num)

		for i = 1, num do
			entities[i] = registry:createEntity()
		end

		return entities
	end

	beforeEach(function(context)
		local registry = Registry.new()

		for _, definition in pairs(Component) do
			registry:defineComponent(definition)
		end

		context.registry = registry
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

	describe("createEntity", function()
		it("should return a valid entity identifier", function(context)
			for _, entity in ipairs(makeEntities(context.registry, 100)) do
				expect(context.registry:entityIsValid(entity)).to.equal(true)
			end
		end)

		it("should increment size when there are no recyclable ids", function(context)
			context.registry:createEntity()
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
					registry:destroyEntity(entity)
					maxDestroyed -= 1

					expect(registry._nextRecyclableEntityId).to.equal(Registry.getId(entity))
				end
			end

			for i, destroyedEntity in ipairs(destroyed) do
				local nextRecyclableEntityId = destroyed[i + 1] and destroyed[i + 1] or NULL_ENTITYID

				expect(Registry.getId(registry:createEntity())).to.equal(destroyedEntity)
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

	describe("createEntityFrom", function()
		it("should return an entity identifier equal to hint when hint's entity id is not in use", function(context)
			expect(context.registry:createEntityFrom(0xDEADBEEE)).to.equal(0xDEADBEEE)
		end)

		it("should return an entity identifier equal to hint when hint's entity id has been recycled", function(context)
			local registry = context.registry
			local entity = makeEntities(registry, 100)[50]

			registry:destroyEntity(entity)

			for _ = 1, 100 do
				registry:destroyEntity(registry:createEntity())
			end

			expect(registry:createEntityFrom(entity)).to.equal(entity)
		end)

		it("should remove entities from the stack of recyclable entities", function(context)
			local registry = context.registry

			makeEntities(registry, 100)

			-- We need to make sure createEntityFrom correctly removes ids from the middle of
			-- the free list. First we populate it with some ids:
			-- 64, 32, 16, 4, 2
			registry:destroyEntity(2)
			registry:destroyEntity(4)
			registry:destroyEntity(16)
			registry:destroyEntity(32)
			registry:destroyEntity(64)

			-- Next we create entity 16, which is in the middle of the free
			-- list. After this operation, the free list should look like this:
			-- 64, 32, 4, 2
			local e16 = registry:createEntityFrom(16)
			expect(Registry.getId(e16)).to.equal(16)
			expect(Registry.getVersion(e16)).to.equal(0)

			-- Now we create entity 64 with an arbitrary version. The free list should
			-- now look like this:
			-- 32, 4, 2
			local version = 16
			local entity = registry:createEntityFrom(bit32.bor(64, bit32.lshift(version, ENTITYID_WIDTH)))
			expect(Registry.getId(entity)).to.equal(64)
			expect(Registry.getVersion(entity)).to.equal(16)

			-- ...
			-- 32, 2
			local e4 = registry:createEntityFrom(4)
			expect(Registry.getId(e4)).to.equal(4)
			expect(Registry.getVersion(e4)).to.equal(0)

			-- Finally we do a couple normal :creates to make sure the free list is in
			-- the proper state
			local e32 = registry:createEntity()
			expect(Registry.getId(e32)).to.equal(32)
			expect(Registry.getVersion(e32)).to.equal(1)

			local e2 = registry:createEntity()
			expect(Registry.getId(e2)).to.equal(2)
			expect(Registry.getVersion(e2)).to.equal(1)
		end)

		it(
			"should return destroy the existing entity and return the same identifier when the entity id is in use",
			function(context)
				local entities = makeEntities(context.registry, 100)
				local entity = entities[38]

				context.registry:addComponent(entity, Component.tag)

				expect(context.registry:createEntityFrom(entity)).to.equal(entity)
				expect(context.registry:entityHas(entity, Component.tag)).to.equal(false)
			end
		)
	end)

	describe("destroyEntity", function()
		it("should remove all components that are on the entity", function(context)
			local registry = context.registry
			local numberPool = registry._pools[Component.number]
			local instancePool = registry._pools[Component.instance]
			local entity = registry:createEntity()

			numberPool:insert(entity, 10)
			instancePool:insert(entity, Instance.new("Hole"))

			registry:destroyEntity(entity)

			expect(numberPool:getIndex(entity)).to.equal(nil)
			expect(instancePool:getIndex(entity)).to.equal(nil)
		end)

		it("should increment the entity's version field", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local entityId = Registry.getId(entity)
			local expectedVersion = 123

			registry:destroyEntity(entity)

			for _ = 1, 122 do
				registry:destroyEntity(registry:createEntity())
			end

			expect(Registry.getVersion(registry._entities[entityId])).to.equal(expectedVersion)
		end)

		it("should push the entity's id onto the free list", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local entityId = Registry.getId(entity)

			registry:destroyEntity(entity)

			expect(registry._nextRecyclableEntityId).to.equal(entityId)
			expect(Registry.getId(registry._entities[entityId])).to.equal(NULL_ENTITYID)
		end)

		it("should error when given an invalid entity", function(context)
			expect(function()
				context.registry:destroyEntity(0)
			end).to.throw()
		end)
	end)

	describe("entityIsValid", function()
		it("should return true if the entity identifier is valid", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			expect(registry:entityIsValid(entity)).to.equal(true)
		end)

		it("should return false if the entity identifier is not valid", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry:destroyEntity(entity)

			expect(registry:entityIsValid(entity)).to.equal(false)
			expect(registry:entityIsValid(NULL_ENTITYID)).to.equal(false)
		end)

		it("should return false if the entity is not a number", function(context)
			expect(context.registry:entityIsValid("entity")).to.equal(false)
		end)
	end)

	describe("entityIsOrphaned", function()
		it("should return true if the entity has no components", function(context)
			expect(context.registry:entityIsOrphaned(context.registry:createEntity())).to.equal(true)
		end)

		it("should return false if the entity has any components", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry:addComponent(entity, Component.number, 10)

			expect(context.registry:entityIsOrphaned(entity)).to.equal(false)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:entityIsOrphaned(0)
			end).to.throw()
		end)
	end)

	describe("visitComponents", function()
		it("should return all component names managed by the registry", function(context)
			local componentDefs = {}

			for componentDef in pairs(context.registry._pools) do
				componentDefs[componentDef] = componentDef
			end

			context.registry:visitComponents(function(componentDef)
				expect(componentDefs[componentDef]).to.equal(componentDef)
				componentDefs[componentDef] = nil
			end)

			expect(next(componentDefs)).to.equal(nil)
		end)

		it("if passed an entity, should return the component names which it has", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			local components = {
				[Component.number] = true,
				[Component.instance] = true,
			}

			registry._pools[Component.number]:insert(entity, 10)
			registry._pools[Component.instance]:insert(entity, Instance.new("Hole"))

			registry:visitComponents(function(definition)
				expect(components[definition]).to.equal(true)
				components[definition] = nil
			end, entity)

			expect(next(components)).to.equal(nil)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:visitComponents(function() end, 0)
			end).to.throw()
		end)
	end)

	describe("entityHas", function()
		it("should return false if the entity does not have the components", function(context)
			local registry = context.registry

			expect(registry:entityHas(registry:createEntity(), Component.instance, Component.number)).to.equal(false)
		end)

		it("should return true if the entity has the components", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry._pools[Component.instance]:insert(entity, Instance.new("Part"))
			registry._pools[Component.number]:insert(entity, 10)

			expect(registry:entityHas(entity, Component.instance, Component.number)).to.equal(true)
		end)

		it("should error if give an invalid entity", function(context)
			expect(function()
				context.registry:entityHas(0, Component.number)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:entityHas(context.registry:createEntity(), "")
			end).to.throw()
		end)
	end)

	describe("entityHasAny", function()
		it("should return false if the entity does not have any of the components", function(context)
			local registry = context.registry

			expect(registry:entityHasAny(registry:createEntity(), Component.instance, Component.number)).to.equal(false)
		end)

		it("should return true if the entity has any of the components", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry._pools[Component.instance]:insert(entity, Instance.new("Part"))
			registry._pools[Component.number]:insert(entity, 10)

			expect(registry:entityHasAny(entity, Component.number, Component.instance)).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:entityHasAny(0, Component.number)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:entityHasAny(context.registry:createEntity(), "")
			end).to.throw()
		end)
	end)

	describe("getComponent", function()
		it("should return the component instance if the entity has the component", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local obj = Instance.new("Hole")

			registry._pools[Component.instance]:insert(entity, obj)
			expect(registry:getComponent(entity, Component.instance)).to.equal(obj)
		end)

		it("should return nil if the entity does not have the component", function(context)
			local registry = context.registry
			expect(registry:getComponent(registry:createEntity(), Component.number)).to.equal(nil)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:getComponent(0, Component.number)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:getComponent(context.registry:createEntity(), "")
			end).to.throw()
		end)
	end)

	describe("addComponent", function()
		it("should add a new component instance to the entity and return it", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local component = Instance.new("Script")
			local obj = registry:addComponent(entity, Component.instance, component)

			expect(registry._pools[Component.instance]:getIndex(entity)).to.be.ok()
			expect(component).to.equal(obj)
		end)

		it("should dispatch the component pool's insertion signal", function(context)
			local registry = context.registry
			local ranCallback

			registry._pools[Component.instance].added:connect(function()
				ranCallback = true
			end)

			registry:addComponent(registry:createEntity(), Component.instance, Instance.new("Hole"))
			expect(ranCallback).to.equal(true)
		end)

		it("should return the correct component instance when a recycled entity is used", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry:destroyEntity(entity)
			entity = registry:createEntity()

			expect(registry:addComponent(entity, Component.instance, Instance.new("Part"))).to.equal(
				registry._pools[Component.instance]:get(entity)
			)
		end)

		it("should correctly handle tag components", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry:addComponent(entity, Component.tag)

			expect(registry._pools[Component.tag]:getIndex(entity)).to.be.ok()
			expect(registry._pools[Component.tag]:get(entity)).to.equal(nil)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:addComponent(0, Component.number, 1)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:addComponent(context.registry:createEntity(), "")
			end).to.throw()
		end)
	end)

	describe("tryAddComponent", function()
		it("should return nil if the component already exists on the entity", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry._pools[Component.number]:insert(entity, 100)

			expect(registry:tryAddComponent(entity, Component.number, 10)).to.equal(nil)
		end)

		it(
			"should add a new component instance to the entity and return it if the component does not exist on the entity",
			function(context)
				local registry = context.registry
				local entity = registry:createEntity()
				local component = Instance.new("Hole")
				local obj = registry:tryAddComponent(entity, Component.instance, component)

				expect(registry._pools[Component.instance]:getIndex(entity)).to.be.ok()
				expect(component).to.equal(obj)
			end
		)

		it("should dispatch the component pool's insertment signal", function(context)
			local registry = context.registry
			local ranCallback

			registry._pools[Component.number].added:connect(function()
				ranCallback = true
			end)

			registry:tryAddComponent(registry:createEntity(), Component.number, 10)
			expect(ranCallback).to.equal(true)
		end)

		it("should return the correct component instance when a recycled entity is used", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry:destroyEntity(entity)
			entity = registry:createEntity()

			expect(registry:tryAddComponent(entity, Component.instance, Instance.new("Hole"))).to.equal(
				registry._pools[Component.instance]:get(entity)
			)
		end)

		it("should correctly handle tag components", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry:tryAddComponent(entity, Component.tag)

			expect(registry._pools[Component.tag]:getIndex(entity)).to.be.ok()
			expect(registry._pools[Component.tag]:get(entity)).to.equal(nil)
		end)

		it("should do nothing if given an invalid entity", function(context)
			context.registry:tryAddComponent(0, Component.number, 0)
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:tryAddComponent(context.registry:createEntity(), "")
			end).to.throw()
		end)
	end)

	describe("getOrAddComponent", function()
		it("should add and return the component if the entity doesn't have it", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			expect(registry:getOrAddComponent(entity, Component.number, 10)).to.equal(10)
		end)

		it("should return the component instance if the entity already has it", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local obj = registry._pools[Component.instance]:insert(entity, Instance.new("Hole"))

			expect(registry:getOrAddComponent(entity, Component.instance, Instance.new("Hole"))).to.equal(obj)
		end)

		it("should dispatch the component pool's added signal", function(context)
			local registry = context.registry
			local ranCallback

			registry._pools[Component.number].added:connect(function()
				ranCallback = true
			end)

			registry:getOrAddComponent(registry:createEntity(), Component.number, 10)
			expect(ranCallback).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:getOrAddComponent(0, Component.number, 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:getOrAddComponent(context.registry:createEntity(), "")
			end).to.throw()
		end)
	end)

	describe("replaceComponent", function()
		it("should replace an existing component instance with a new one", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local obj = Instance.new("Hole")

			registry._pools[Component.instance]:insert(entity, Instance.new("Hole"))
			expect(registry:replaceComponent(entity, Component.instance, obj)).to.equal(obj)
			expect(registry._pools[Component.instance]:get(entity)).to.equal(obj)
		end)

		it("should dispatch the component pool's update signal", function(context)
			local registry = context.registry
			local new = 11
			local ranCallback

			registry._pools[Component.number].updated:connect(function(_, newComponent)
				expect(newComponent).to.equal(new)
				ranCallback = true
			end)

			local entity = registry:createEntity()
			registry._pools[Component.number]:insert(entity, 10)
			registry:replaceComponent(entity, Component.number, 11)

			expect(ranCallback).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:replaceComponent(0, Component.number, 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:replaceComponent(context.registry:createEntity(), "")
			end).to.throw()
		end)

		it("should error if the entity does not have the component", function(context)
			expect(function()
				context.registry:replaceComponent(context.registry:createEntity(), Component.number, 0)
			end).to.throw()
		end)
	end)

	describe("addOrReplaceComponent", function()
		it("should add the component if it does not exist on the entity", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local added = 10

			expect(registry:addOrReplaceComponent(entity, Component.number, added)).to.equal(added)
			expect(registry._pools[Component.number]:get(entity)).to.equal(added)
		end)

		it("should dispatch the component pool's added signal", function(context)
			local registry = context.registry
			local ranAddCallback

			registry._pools[Component.instance].added:connect(function()
				ranAddCallback = true
			end)

			registry:addOrReplaceComponent(registry:createEntity(), Component.instance, Instance.new("Hole"))
			expect(ranAddCallback).to.equal(true)
		end)

		it("should replace the component if it already exists on the entity", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local replaced = 12

			expect(registry:addOrReplaceComponent(entity, Component.number, replaced)).to.equal(replaced)
			expect(registry._pools[Component.number]:get(entity)).to.equal(replaced)
		end)

		it("should dispatch the component pool's replaced signal", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local ranReplaceCallback = false

			registry._pools[Component.instance].updated:connect(function()
				ranReplaceCallback = true
			end)

			registry._pools[Component.instance]:insert(entity, Instance.new("Hole"))
			registry:addOrReplaceComponent(entity, Component.instance, Instance.new("Hole"))

			expect(ranReplaceCallback).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:addOrReplaceComponent(0, Component.number, 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:addOrReplaceComponent(context.registry:createEntity(), "")
			end).to.throw()
		end)
	end)

	describe("removeComponent", function()
		it("should remove a component that has been added to the entity", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry._pools[Component.number]:insert(entity, 12)
			registry:removeComponent(entity, Component.number)

			expect(registry._pools[Component.number]:getIndex(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local ranCallback

			registry._pools[Component.number].removed:connect(function()
				ranCallback = true
			end)

			registry._pools[Component.number]:insert(entity, 100)
			registry:removeComponent(entity, Component.number)

			expect(ranCallback).to.equal(true)
		end)

		it("should error if given an invalid entity", function(context)
			expect(function()
				context.registry:removeComponent(0, Component.number, 0)
			end).to.throw()
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:removeComponent(context.registry:createEntity(), "")
			end).to.throw()
		end)

		it("should error if the entity does not have the component", function(context)
			expect(function()
				context.registry:removeComponent(context.registry:createEntity(), Component.number)
			end).to.throw()
		end)
	end)

	describe("tryRemoveComponent", function()
		it("should do nothing if the component does not exist on the entity", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry:tryRemoveComponent(entity, Component.instance)
		end)

		it("should remove a component if it exists on the entity", function(context)
			local registry = context.registry
			local entity = registry:createEntity()

			registry._pools[Component.number]:insert(entity, 10)
			registry:tryRemoveComponent(entity, Component.number)

			expect(registry._pools[Component.number]:getIndex(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local registry = context.registry
			local entity = registry:createEntity()
			local ranCallback

			registry._pools[Component.number].removed:connect(function()
				ranCallback = true
			end)

			registry._pools[Component.number]:insert(entity, 10)
			registry:tryRemoveComponent(entity, Component.number)

			expect(ranCallback).to.equal(true)
		end)

		it("should do nothing if given an invalid entity", function(context)
			context.registry:tryRemoveComponent(0, Component.number)
		end)

		it("should error if given an invalid component name", function(context)
			expect(function()
				context.registry:tryRemoveComponent(context.registry:createEntity(), "")
			end).to.throw()
		end)
	end)

	describe("each", function()
		it("should iterate over all non-destroyed entities", function(context)
			local registry = context.registry
			local entities = {}

			for i = 1, 128 do
				entities[i] = registry:createEntity()
			end

			for i, entity in ipairs(entities) do
				if i % 16 == 0 then
					registry:destroyEntity(entity)
				end
			end

			-- make some entities which will have incremented versions
			registry:createEntity()
			registry:createEntity()
			registry:createEntity()

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
				entities[i] = registry:createEntity()
			end

			for i, entity in ipairs(entities) do
				if i % 16 == 0 then
					count = count - 1
					registry:destroyEntity(entity)
				end
			end

			expect(registry:countEntities()).to.equal(count)
		end)
	end)

	describe("getPools", function()
		it("should return the pools for the specified component types", function(context)
			local registry = context.registry
			local pools = registry:getPools({ Component.number, Component.instance })

			expect(pools[1]).to.equal(registry._pools[Component.number])
			expect(pools[2]).to.equal(registry._pools[Component.instance])
		end)
	end)
end

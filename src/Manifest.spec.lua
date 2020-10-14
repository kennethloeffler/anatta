return function()
	local Constants = require(script.Parent.Constants)
	local Manifest = require(script.Parent.Manifest)
	local Pool = require(script.Parent.Pool)
	local t = require(script.Parent.core.TypeDef)

	local ENTITYID_MASK = Constants.ENTITYID_MASK
	local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
	local NULL_ENTITYID = Constants.NULL_ENTITYID

	local function makeEntities(manifest, num)
		local entities = table.create(num)

		for i = 1, num do
			entities[i] = manifest:create()
		end

		return entities
	end

	local function instanceConstructor()
		return Instance.new("Part")
	end

	beforeEach(function(context)
		local manifest = Manifest.new()
		local interfaceComponent = manifest:define("interface", t.interface { instance = t.instance })
		local instanceComponent = manifest:define("instance", t.Instance, instanceConstructor)
		local primitiveComponent = manifest:define("primitive", t.number)

		context.manifest = manifest
		context.interfaceComponent = interfaceComponent
		context.instanceComponent = instanceComponent
		context.primitiveComponent = primitiveComponent
	end)

	describe("new", function()
		it("should construct a new empty Manifest instance", function()
			local manifest = Manifest.new()

			expect(getmetatable(manifest)).to.equal(Manifest)
			expect(manifest.size).to.equal(0)
			expect(manifest.nextRecyclable).to.equal(NULL_ENTITYID)
			expect(manifest.null).to.equal(NULL_ENTITYID)
			expect(manifest.entities).to.be.a("table")
			expect(next(manifest.entities)).to.equal(nil)
			expect(manifest.pools).to.be.a("table")
			expect(next(manifest.pools)).to.equal(nil)
			expect(manifest.t).to.equal(t)
			expect(manifest.contexts).to.be.a("table")
			expect(next(manifest.contexts)).to.equal(nil)
		end)
	end)

	describe("define", function()
		it("should create a new pool", function(context)
			local pool = context.manifest.pools[context.primitiveComponent]

			expect(pool).to.be.a("table")
			expect(getmetatable(pool)).to.equal(Pool)
		end)

		it("should generate and return the component id", function(context)
			expect(context.primitiveComponent).to.be.a("number")
		end)

		it("should inject constructors", function(context)
			expect(context.manifest.contexts["constructor_" .. context.instanceComponent]).to.equal(instanceConstructor)
		end)

		it("should attach removal signal listeners to destroy instance types or members", function(context)
			local manifest = context.manifest
			local instanceComponent = context.instanceComponent
			local interfaceComponent = context.interfaceComponent
			local instancePool = manifest.pools[instanceComponent]
			local interfacePool = manifest.pools[interfaceComponent]

			local entity = manifest:create()
			local instance = instancePool:assign(entity, Instance.new("Part"))

			instancePool.onRemove:dispatch(entity, instance)

			expect(function()
				instance.Parent = workspace
			end).to.throw()

			local interface = interfacePool:assign(entity, { instance = Instance.new("Script") })

			interfacePool.onRemove:dispatch(entity, interface)

			expect(function()
				interface.instance.Parent = workspace
			end).to.throw()
		end)
	end)

	describe("create", function()
		it("should return a valid entity identifier", function(context)
			for _, entity in ipairs(makeEntities(context.manifest, 100)) do
				expect(context.manifest:valid(entity)).to.equal(true)
			end
		end)

		it("should increment size when there are no recyclable ids", function(context)
			context.manifest:create()
			expect(context.manifest.size).to.equal(1)
		end)

		it("should recycle the ids of destroyed entities", function(context)
			local manifest = context.manifest
			local num = 50
			local destroyedIds = table.create(num)

			for i, entity in ipairs(makeEntities(manifest, 100)) do
				if i % 2 == 0 then
					-- fill the table in reverse order so it will be in the same
					-- order that the ids will be recycled in
					destroyedIds[num] = bit32.band(entity, ENTITYID_MASK)
					manifest:destroy(entity)
					num -= 1

					expect(manifest.nextRecyclable).to.equal(bit32.band(entity, ENTITYID_MASK))
				end
			end

			for i, destroyedId in ipairs(destroyedIds) do
				local nextRecyclable = destroyedIds[i + 1] and destroyedIds[i + 1] or NULL_ENTITYID

				expect(bit32.band(manifest:create(), ENTITYID_MASK)).to.equal(destroyedId)
				expect(manifest.nextRecyclable).to.equal(nextRecyclable)

				if i < 50 then
					expect(bit32.band(manifest.entities[nextRecyclable], ENTITYID_MASK))
						.to.equal(destroyedIds[i + 2] or NULL_ENTITYID)
				end
			end
		end)
	end)

	describe("createFrom", function()

		it("should return an entity identifier equal to hint when hint's entity id is not in use", function(context)
			expect(context.manifest:createFrom(0xDEADBEEF)).to.equal(0xDEADBEEF)
		end)

		it("should return an entity identifier equal to hint when hint's entity id has been recycled", function(context)
			local manifest = context.manifest
			local entity = makeEntities(manifest, 100)[50]

			manifest:destroy(entity)

			for _ = 1, 100 do
				manifest:destroy(manifest:create())
			end

			expect(manifest:createFrom(entity)).to.equal(entity)
		end)

		it("should properly remove an entity from the stack of recyclable entities", function(context)
			local manifest = context.manifest

			makeEntities(manifest, 100)

			manifest:destroy(2)
			manifest:destroy(4)
			manifest:destroy(16)
			manifest:destroy(32)
			manifest:destroy(64)

			expect(manifest:createFrom(16)).to.equal(16)
			expect(manifest:createFrom(bit32.bor(64, bit32.lshift(16, ENTITYID_WIDTH))))
				.to.equal(bit32.bor(64, bit32.lshift(16, ENTITYID_WIDTH)))
			expect(manifest:createFrom(4)).to.equal(4)

			expect(bit32.band(manifest:create(), ENTITYID_MASK)).to.equal(32)
			expect(bit32.band(manifest:create(), ENTITYID_MASK)).to.equal(2)
		end)

		it("should return a brand new entity identifier when the entity id is in use", function(context)
			local entity = makeEntities(context.manifest, 100)[60]

			expect(context.manifest:createFrom(entity)).to.equal(context.manifest.size)
		end)
	end)

	describe("destroy", function()
		it("should remove all components that are on the entity", function(context)
			local manifest = context.manifest
			local primitivePool = manifest.pools[context.primitiveComponent]
			local instancePool = manifest.pools[context.instanceComponent]
			local entity = manifest:create()

			primitivePool:assign(entity, 10)
			instancePool:assign(entity, Instance.new("Hole"))

			manifest:destroy(entity)

			expect(primitivePool:has(entity)).to.equal(nil)
			expect(instancePool:has(entity)).to.equal(nil)
		end)

		it("should increment the entity's version field", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local entityId = bit32.band(entity, ENTITYID_MASK)
			local expectedVersion = 123

			manifest:destroy(entity)

			for _ = 1, 122 do
				manifest:destroy(manifest:create())
			end

			expect(bit32.rshift(manifest.entities[entityId], ENTITYID_WIDTH)).to.equal(expectedVersion)
		end)

		it("should push the entity's id onto the free list", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local entityId = bit32.band(entity, ENTITYID_MASK)

			manifest:destroy(entity)

			expect(manifest.nextRecyclable).to.equal(entityId)
			expect(bit32.band(manifest.entities[entityId], ENTITYID_MASK)).to.equal(NULL_ENTITYID)
		end)
	end)

	describe("valid", function()
		it("should return true if the entity identifier is valid", function(context)
			local manifest = context.manifest

			expect(manifest:valid(manifest:create())).to.equal(true)
		end)

		it("should return false if the entity identifier is not valid", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest:destroy(entity)

			expect(manifest:valid(entity)).to.equal(false)
			expect(manifest:valid(NULL_ENTITYID)).to.equal(false)
		end)
	end)

	describe("stub", function()
		it("should return true if the entity has no components", function(context)
			expect(context.manifest:stub(context.manifest:create())).to.equal(true)
		end)

		it("should return false if the entity has any components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest:add(entity, context.primitiveComponent, 10)

			expect(context.manifest:stub(entity)).to.equal(false)
		end)
	end)

	describe("visit", function()
		it("should return the component identifiers managed by the manifest", function(context)
			local num = 0

			context.manifest:visit(function(componentId)
				expect(context.manifest.pools[componentId]).to.be.ok()
				num += 1
			end)

			expect(num).to.equal(#context.manifest.pools)
		end)

		it("if passed an entity, should return the component ids which it has", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest.pools[context.primitiveComponent]:assign(entity, 10)
			manifest.pools[context.instanceComponent]:assign(entity, Instance.new("Hole"))

			manifest:visit(function(componentId)
				expect(manifest.pools[componentId]:has(entity)).to.be.ok()
			end, entity)
		end)
	end)

	describe("has", function()
		it("should return false if the entity does not have the components", function(context)
			local manifest = context.manifest
			local instanceComponent = context.instanceComponent
			local primitiveComponent = context.primitiveComponent

			expect(manifest:has(manifest:create(), instanceComponent, primitiveComponent)).to.equal(false)
		end)

		it("should return true if the entity has the components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local instanceComponent = context.instanceComponent
			local primitiveComponent = context.primitiveComponent

			manifest.pools[instanceComponent]:assign(entity, Instance.new("Part"))
			manifest.pools[primitiveComponent]:assign(entity, 10)

			expect(manifest:has(entity, instanceComponent, primitiveComponent)).to.equal(true)
		end)
	end)

	describe("any", function()
		it("should return false if the entity does not have any of the components", function(context)
			local manifest = context.manifest
			local primitiveComponent = context.primitiveComponent
			local instanceComponent = context.instanceComponent

			expect(manifest:any(manifest:create(), instanceComponent, primitiveComponent)).to.equal(false)
		end)

		it("should return true if the entity has any of the components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local primitiveComponent = context.primitiveComponent
			local instanceComponent = context.instanceComponent

			manifest.pools[instanceComponent]:assign(entity, Instance.new("Part"))
			manifest.pools[primitiveComponent]:assign(entity, 10)

			expect(manifest:any(entity, primitiveComponent, instanceComponent)).to.equal(true)
		end)
	end)

	describe("get", function()
		it("should return the component instance if the entity has the component", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local obj = Instance.new("Hole")

			manifest.pools[context.instanceComponent]:assign(entity, obj)
			expect(manifest:get(entity, context.instanceComponent)).to.equal(obj)
		end)
	end)

	describe("tryGet", function()
		it("should return nil if the entity does not have the component", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			expect(manifest:tryGet(entity, context.primitiveComponent)).to.never.be.ok()
		end)

		it("should return the component instance if the entity has the component", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local obj = { instance = Instance.new("Hole") }

			manifest.pools[context.interfaceComponent]:assign(entity, obj)
			expect(manifest:tryGet(entity, context.interfaceComponent)).to.equal(obj)
		end)

	end)

	describe("multiGet", function()
		it("should return the specified components on the entity in order", function(context)
			local manifest = context.manifest
			local instanceComponent = context.instanceComponent
			local primitiveComponent = context.primitiveComponent
			local entity = manifest:create()
			local tab = table.create(2)
			local component1 = { instance = Instance.new("Script") }
			local component2 = 10

			manifest.pools[instanceComponent]:assign(entity, component1)
			manifest.pools[primitiveComponent]:assign(entity, component2)

			local result1, result2 = manifest:multiGet(entity, tab, instanceComponent, primitiveComponent)

			expect(result1).to.equal(component1)
			expect(result2).to.equal(component2)
		end)
	end)

	describe("add", function()
		it("should add a new component instance to the entity and return it", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local component = Instance.new("Script")
			local obj = manifest:add(entity, context.instanceComponent, component)

			expect(manifest.pools[context.instanceComponent]:has(entity)).to.be.ok()
			expect(component).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment signal", function(context)
			local manifest = context.manifest
			local ranCallback

			manifest.pools[context.instanceComponent].onAdd:connect(function()
				ranCallback = true
			end)

			manifest:add(manifest:create(), context.instanceComponent, Instance.new("Hole"))
			expect(ranCallback).to.equal(true)
		end)

		it("should return the correct component instance when a recycled entity is used", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest:destroy(entity)
			entity = manifest:create()

			expect(manifest:add(entity, context.instanceComponent, Instance.new("Part")))
				.to.equal(manifest.pools[context.instanceComponent]:get(entity))
		end)

		it("should correctly handle tag components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local tag = manifest:define("tag", t.none)

			manifest:add(entity, tag)

			expect(manifest.pools[tag]:has(entity)).to.be.ok()
			expect(manifest.pools[tag]:get(entity)).to.equal(nil)
		end)
	end)

	describe("tryAdd", function()
		it("should return nil if the component already exists on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest.pools[context.primitiveComponent]:assign(entity, 100)

			expect(manifest:tryAdd(entity, context.primitiveComponent)).to.equal(nil)
		end)

		it("should add a new component instance to the entity and return it if the component does not exist on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local component = Instance.new("Hole")
			local obj = manifest:tryAdd(entity, context.instanceComponent, component)

			expect(manifest.pools[context.instanceComponent]:has(entity)).to.be.ok()
			expect(component).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment signal", function(context)
			local manifest = context.manifest
			local ranCallback

			manifest.pools[context.primitiveComponent].onAdd:connect(function()
				ranCallback = true
			end)

			manifest:tryAdd(manifest:create(), context.primitiveComponent, 10)
			expect(ranCallback).to.equal(true)
		end)

		it("should return the correct component instance when a recycled entity is used", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest:destroy(entity)
			entity = manifest:create()

			expect(manifest:tryAdd(entity, context.instanceComponent, Instance.new("Hole")))
				.to.equal(manifest.pools[context.instanceComponent]:get(entity))
		end)

		it("should correctly handle tag components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local tag = manifest:define("tag", t.none)

			manifest:tryAdd(entity, tag)

			expect(manifest.pools[tag]:has(entity)).to.be.ok()
			expect(manifest.pools[tag]:get(entity)).to.equal(nil)
		end)

	end)
	describe("multiAdd", function()
		it("should add all of the specified components to the entity then return the entity", function(context)
			local manifest = context.manifest
			local component1 = Instance.new("Hole")
			local component2 = { instance = Instance.new("Hole") }
			local component3 = 10
			local pool1 = manifest.pools[context.instanceComponent]
			local pool2 = manifest.pools[context.interfaceComponent]
			local pool3 = manifest.pools[context.primitiveComponent]
			local entity = manifest:multiAdd(manifest:create(),
				context.instanceComponent, component1,
				context.interfaceComponent, component2,
				context.primitiveComponent, component3)

			expect(pool1:get(entity)).to.equal(component1)
			expect(pool2:get(entity)).to.equal(component2)
			expect(pool3:get(entity)).to.equal(component3)
		end)
	end)

	describe("getOrAdd", function()
		it("should add and return the component if the entity doesn't have it", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			expect(manifest:getOrAdd(entity, context.primitiveComponent, 10)).to.equal(10)
		end)

		it("should return the component instance if the entity already has it", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local obj = manifest.pools[context.instanceComponent]:assign(entity, Instance.new("Hole"))

			expect(manifest:getOrAdd(entity, context.instanceComponent, Instance.new("Hole"))).to.equal(obj)
		end)

		it("should dispatch the component pool's added signal", function(context)
			local manifest =  context.manifest
			local ranCallback

			manifest.pools[context.primitiveComponent].onAdd:connect(function()
				ranCallback = true
			end)

			manifest:getOrAdd(manifest:create(), context.primitiveComponent, 10)
			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("replace", function()
		it("should replace an existing component instance with a new one", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local obj = Instance.new("Hole")

			manifest.pools[context.instanceComponent]:assign(entity, Instance.new("Hole"))
			expect(manifest:replace(entity, context.instanceComponent, obj)).to.equal(obj)
			expect(manifest.pools[context.instanceComponent]:get(entity)).to.equal(obj)
		end)

		it("should dispatch the component pool's update signal", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local ranCallback

			manifest.pools[context.primitiveComponent].onUpdate:connect(function()
				ranCallback = true
			end)

			manifest.pools[context.primitiveComponent]:assign(entity, 10)
			manifest:replace(entity, context.primitiveComponent, 11)

			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("addOrReplace", function()
		it("should add the component if it does not exist on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local added = 10

			expect(manifest:addOrReplace(entity, context.primitiveComponent, added)).to.equal(added)
			expect(manifest.pools[context.primitiveComponent]:get(entity)).to.equal(added)
		end)

		it("should dispatch the component pool's added signal", function(context)
			local manifest = context.manifest
			local ranAddCallback

			manifest.pools[context.instanceComponent].onAdd:connect(function()
				ranAddCallback = true
			end)

			manifest:addOrReplace(manifest:create(), context.instanceComponent, Instance.new("Hole"))
			expect(ranAddCallback).to.equal(true)
		end)

		it("should replace the component if it already exists on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local replaced = 12

			expect(manifest:addOrReplace(entity, context.primitiveComponent, replaced)).to.equal(replaced)
			expect(manifest.pools[context.primitiveComponent]:get(entity)).to.equal(replaced)
		end)

		it("should dispatch the component pool's replacement signal", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local ranReplaceCallback = false

			manifest.pools[context.instanceComponent].onUpdate:connect(function()
				ranReplaceCallback = true
			end)

			manifest.pools[context.instanceComponent]:assign(entity, Instance.new("Hole"))
			manifest:addOrReplace(entity, context.instanceComponent, Instance.new("Hole"))

			expect(ranReplaceCallback).to.equal(true)
		end)
	end)

	describe("remove", function()
		it("should remove a component that has been added to the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest.pools[context.primitiveComponent]:assign(entity, 12)
			manifest:remove(entity, context.primitiveComponent)

			expect(manifest.pools[context.primitiveComponent]:has(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local ranCallback

			manifest.pools[context.primitiveComponent].onRemove:connect(function()
				ranCallback = true
			end)

			manifest.pools[context.primitiveComponent]:assign(entity, 100)
			manifest:remove(entity, context.primitiveComponent)

			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("multiRemove", function()
		it("should remove all of the specified components from the entity and dispatch each components' removal signals", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local primitiveComponent = context.primitiveComponent
			local instanceComponent = context.instanceComponent
			local interfaceComponent = context.interfaceComponent

			local component1 = manifest.pools[primitiveComponent]:assign(entity, 10)
			local component2 = manifest.pools[instanceComponent]:assign(entity, Instance.new("Hole"))
			local component3 = manifest.pools[interfaceComponent]:assign(entity, { instance = Instance.new("Part") })
			local component1ok = false
			local component2ok = false
			local component3ok = false

			manifest.pools[primitiveComponent].onRemove:connect(function(e, component)
				expect(e).to.equal(entity)
				expect(component).to.equal(component1)
				component1ok = true
			end)

			manifest.pools[instanceComponent].onRemove:connect(function(e, component)
				expect(e).to.equal(entity)
				expect(component).to.equal(component2)
				component2ok = true
			end)

			manifest.pools[interfaceComponent].onRemove:connect(function(e, component)
				expect(e).to.equal(entity)
				expect(component).to.equal(component3)
				component3ok = true
			end)

			manifest:multiRemove(entity, primitiveComponent, instanceComponent, interfaceComponent)

			expect(component1ok).to.equal(true)
			expect(component2ok).to.equal(true)
			expect(component3ok).to.equal(true)
			expect(manifest.pools[primitiveComponent]:has(entity)).to.equal(nil)
			expect(manifest.pools[instanceComponent]:has(entity)).to.equal(nil)
			expect(manifest.pools[interfaceComponent]:has(entity)).to.equal(nil)
		end)
	end)

	describe("tryRemove", function()
		it("should return false if the component does not exist on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			expect(manifest:tryRemove(entity, context.instanceComponent)).to.equal(false)
		end)

		it("should remove a component if it exists on the entity and return true", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest.pools[context.primitiveComponent]:assign(entity, 10)
			expect(manifest:tryRemove(entity, context.primitiveComponent)).to.equal(true)

			expect(manifest.pools[context.primitiveComponent]:has(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local ranCallback

			manifest.pools[context.primitiveComponent].onRemove:connect(function()
				ranCallback = true
			end)

			manifest.pools[context.primitiveComponent]:assign(entity, 10)
			manifest:tryRemove(entity, context.primitiveComponent)

			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("onAdded", function()
		it("should return the added signal for one specified component", function(context)
			local manifest = context.manifest

			expect(manifest:onAdded(context.primitiveComponent))
				.to.equal(manifest.pools[context.primitiveComponent].onAdd)
		end)

		it("should return a new signal for more than one specified component that fires once all have been added", function(context)
			local manifest = context.manifest
			local test1 = manifest:define("test1", t.none)
			local test2 = manifest:define("test2", t.none)
			local test3 = manifest:define("test3", t.none)
			local fired = false
			local e = manifest:create()

			manifest:onAdded(test1, test2, test3):connect(function(entity)
				expect(entity).to.equal(e)
				fired = true
			end)

			manifest:add(e, test1)
			manifest:add(e, test2)
			manifest:add(e, test3)
			expect(fired).equal(true)
		end)
	end)

	describe("onRemoved", function()
		it("should return the removed signal for the specified component", function(context)
			local manifest = context.manifest

			expect(manifest:onRemoved(context.instanceComponent))
				.to.equal(manifest.pools[context.instanceComponent].onRemove)
		end)

		it("should return a new signal for more than one specified component that fires after any have been removed from an entity that has all of them", function(context)
			local manifest = context.manifest
			local test1 = manifest:define("test1", t.none)
			local test2 = manifest:define("test2", t.none)
			local test3 = manifest:define("test3", t.none)
			local fired = false
			local e = manifest:create()

			manifest:onRemoved(test1, test2, test3):connect(function(entity)
				expect(entity).to.equal(e)
				fired = true
			end)

			manifest:add(e, test1)
			manifest:add(e, test2)
			manifest:add(e, test3)
			manifest:remove(e, test2)

			expect(fired).to.equal(true)
			fired = false

			manifest:remove(e, test1)
			expect(fired).to.equal(false)
		end)

	end)

	describe("onUpdated", function()
		it("should return the update signal for the specified component", function(context)
			local manifest = context.manifest

			expect(manifest:onUpdated(context.primitiveComponent))
				.to.equal(manifest.pools[context.primitiveComponent].onUpdate)
		end)
	end)

	describe("forEach", function()
		it("should iterate over all non-destroyed entities", function(context)
			local manifest = context.manifest
			local entities = {}

			for i = 1, 128 do
				entities[i] = manifest:create()
			end

			for i, entity in ipairs(entities) do
				if i % 16 == 0 then
					manifest:destroy(entity)
				end
			end

			-- make some entities which will have incremented versions
			manifest:create()
			manifest:create()
			manifest:create()

			manifest:each(function(entity)
				local id = bit32.band(entity, ENTITYID_MASK)

				expect(id).to.equal(bit32.band(manifest.entities[id], ENTITYID_MASK))
			end)
		end)
	end)

	describe("numEntities", function()
		it("should return the number of non-destroyed entities currently in the manifest", function(context)
			local manifest = context.manifest
			local numEntities = 128
			local entities = table.create(numEntities)

			for i = 1, numEntities do
				entities[i] = manifest:create()
			end

			for i, entity in ipairs(entities) do
				if i % 16 == 0 then
					numEntities = numEntities - 1
					manifest:destroy(entity)
				end
			end

			expect(manifest:numEntities()).to.equal(numEntities)
		end)
	end)

	describe("getPool", function()
		it("should return the pool for the specified component type", function(context)
			local manifest = context.manifest

			expect(manifest:getPool(context.primitiveComponent))
				.to.equal(manifest.pools[context.primitiveComponent])
		end)
	end)
end

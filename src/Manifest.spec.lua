return function()
	local Constants = require(script.Parent.Constants)
	local Manifest = require(script.Parent.Manifest)
	local t = require(script.Parent.core.TypeDef)

	beforeEach(function(context)
		local manifest = Manifest.new()

		context.manifest = manifest
		context.testComponent = manifest:define("test", t.table)
	end)

	describe("new", function()
		it("should construct a new empty Manifest instance", function()
			local manifest = Manifest.new()

			expect(manifest.size).to.equal(0)
			expect(manifest.nextRecyclable).to.equal(Constants.NULL_ENTITYID)
			expect(#manifest.entities).to.equal(0)
			expect(#manifest.pools).to.equal(0)
			expect(#manifest.ident).to.equal(0)
		end)
	end)

	describe("define", function()
		it("should create a valid component pool", function(context)
			expect(context.manifest.pools[context.testComponent]).to.be.ok()
		end)

		it("should generate and return the component id", function(context)
			expect(context.testComponent).to.be.ok()
			expect(context.testComponent).to.be.a("number")
		end)

		it("should attach removal signal listeners to destroy instance types or members", function(context)
			local manifest = context.manifest

			local instanceType = manifest:define("myInstance", t.instanceOf("Script"))
			local entity = manifest:create()
			local instance = manifest.pools[instanceType]:assign(entity, Instance.new("Script"))

			manifest.pools[instanceType].onRemove:dispatch(entity, instance)
			expect(function()
				instance.Parent = workspace
			end).to.throw()

			local interfaceWithInstanceType = manifest:define("myInterface",
				t.interface { instanceField = t.Instance })
			entity = manifest:create()
			instance = manifest.pools[interfaceWithInstanceType]:assign(entity,
				{ instanceField = Instance.new("Part") })

			manifest.pools[interfaceWithInstanceType].onRemove:dispatch(entity, instance)
			expect(function()
				instance.instanceField.Parent = workspace
			end).to.throw()
		end)
	end)

	describe("create", function()
		it("should return a valid entity identifier", function(context)
			local entity = context.manifest:create()

			expect(context.manifest:valid(entity)).to.equal(true)
		end)

		it("should recycle the ids of destroyed entities", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local entityId = bit32.band(entity, Constants.ENTITYID_MASK)

			manifest:destroy(entity)

			expect(bit32.band(manifest:create(), Constants.ENTITYID_MASK)).to.equal(entityId)
		end)

		it("should pop the ids of destroyed entities off of the free list", function(context)
			local manifest = context.manifest
			local e1 = manifest:create()
			local e2 = manifest:create()

			manifest:destroy(e1)
			manifest:destroy(e2)
			manifest:create()

			expect(manifest.nextRecyclable).to.equal(bit32.band(e1, Constants.ENTITYID_MASK))

			-- spooky implementation details...
			expect(bit32.band(manifest.entities[manifest.nextRecyclable], Constants.ENTITYID_MASK))
				.to.equal(Constants.NULL_ENTITYID)
		end)
	end)

	describe("createFrom", function()
		local numEntities = 100

		it("should return an entity identifier equal to hint when hint's entity id is not in use", function(context)
			expect(context.manifest:createFrom(0xDEADBEEF)).to.equal(0xDEADBEEF)
		end)

		it("should return an entity identifier equal to hint when hint's entity id has been recycled", function(context)
			local manifest = context.manifest

			for _ = 1, numEntities do
				manifest:create()
			end

			manifest:destroy(50)

			for _ = 1, 100 do
				-- all of these will have entity id == 50
				manifest:destroy(manifest:create())
			end

			expect(manifest:createFrom(50)).to.equal(50)
		end)

		it("should properly remove an entity from the stack of recyclable entities", function(context)
			local manifest = context.manifest

			for _ = 1, numEntities do
				manifest:create()
			end

			manifest:destroy(2)
			manifest:destroy(4)
			manifest:destroy(16)
			manifest:destroy(32)
			manifest:destroy(64)

			expect(manifest:createFrom(16)).to.equal(16)
			expect(manifest:createFrom(bit32.bor(64, bit32.lshift(16, Constants.ENTITYID_WIDTH))))
				.to.equal(bit32.bor(64, bit32.lshift(16, Constants.ENTITYID_WIDTH)))
			expect(manifest:createFrom(4)).to.equal(4)

			expect(bit32.band(manifest:create(), Constants.ENTITYID_MASK)).to.equal(32)
			expect(bit32.band(manifest:create(), Constants.ENTITYID_MASK)).to.equal(2)
		end)

		it("should return a brand new entity identifier when the entity id is in use", function(context)
			for _ = 1, numEntities do
				context.manifest:create()
			end

			expect(context.manifest:createFrom(numEntities - 1)).to.equal(numEntities + 1)
		end)
	end)

	describe("destroy", function()
		it("should remove all components that were on the entity", function(context)
			local entity = context.manifest:create()

			context.manifest.pools[context.testComponent]:assign(entity, context.testComponent, {})
			context.manifest:destroy(entity)

			expect(context.manifest.pools[context.testComponent]:has(entity)).to.equal(nil)
		end)

		it("should increment the entity's version field", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local entityId = bit32.band(entity, Constants.ENTITYID_MASK)

			manifest:destroy(entity)

			expect(bit32.rshift(manifest.entities[entityId], Constants.ENTITYID_WIDTH)).to.equal(1)
		end)

		it("should push the entity's id onto the free list", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local entityId = bit32.band(entity, Constants.ENTITYID_MASK)

			manifest:destroy(entity)

			expect(manifest.nextRecyclable).to.equal(entityId)
			expect(bit32.band(manifest.entities[entityId], Constants.ENTITYID_MASK)).to.equal(Constants.NULL_ENTITYID)
		end)
	end)

	describe("valid", function()
		it("should return true if the entity identifier is valid", function(context)
			expect(context.manifest:valid(context.manifest:create())).to.equal(true)
		end)

		it("should return false if the entity identifier is not valid", function(context)
			local entity = context.manifest:create()

			context.manifest:destroy(entity)

			expect(context.manifest:valid(entity)).to.equal(false)
		end)
	end)

	describe("stub", function()
		it("should return true if the entity has no components", function(context)
			expect(context.manifest:stub(context.manifest:create())).to.equal(true)
		end)

		it("should return false if the entity has any components", function(context)
			local entity = context.manifest:create()

			context.manifest:add(entity, context.testComponent, {})

			expect(context.manifest:stub(entity)).to.equal(false)
		end)
	end)

	describe("visit", function()
		beforeEach(function(context)
			local manifest = context.manifest

			context.types = {
				[context.testComponent] = true,
				[manifest:define("test1", t.none)] = true,
				[manifest:define("test2", t.none)] = true,
				[manifest:define("test3", t.none)] = true
			}
		end)

		it("should return the component identifiers managed by the manifest", function(context)
			context.manifest:visit(function(component)
				expect(context.types[component]).to.be.ok()
			end)
		end)

		it("if passed an entity, should return the component identifiers which it has", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest.pools[manifest:T "test1"]:assign(entity)
			manifest.pools[manifest:T "test2"]:assign(entity)

			manifest:visit(function(component)
				expect(manifest.pools[component]:has(entity)).to.be.ok()
			end, entity)
		end)
	end)

	describe("has", function()
		it("should return false if the entity does not have the components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local testComponent2 = manifest:define("testComponent2", t.none)

			expect(manifest:has(entity, context.testComponent, testComponent2)).to.equal(false)
		end)

		it("should return true if the entity has the components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local testComponent2 = manifest:define("testComponent2", t.none)

			manifest.pools[context.testComponent]:assign(entity)
			manifest.pools[testComponent2]:assign(entity)
			expect(manifest:has(entity, context.testComponent, testComponent2)).to.equal(true)
		end)
	end)

	describe("any", function()
		it("should return false if the entity does not have any of the components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local testComponent2 = manifest:define("testComponent2", t.none)

			expect(manifest:any(entity, context.testComponent, testComponent2)).to.equal(false)
		end)

		it("should return true if the entity has any of the components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local testComponent2 = manifest:define("testComponent2", t.none)

			manifest.pools[testComponent2]:assign(entity)

			expect(manifest:any(entity, context.testComponent, testComponent2)).to.equal(true)
		end)
	end)

	describe("get", function()
		it("should return the component instance if the entity has the component", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local obj = {}

			manifest.pools[context.testComponent]:assign(entity, obj)
			expect(manifest:get(entity, context.testComponent)).to.equal(obj)
		end)
	end)

	describe("maybeGet", function()
		it("should return nil if the entity does not have the component", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			expect(manifest:maybeGet(entity, context.testComponent)).to.never.be.ok()
		end)

		it("should return the component instance if the entity has the component", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local obj = {}

			manifest.pools[context.testComponent]:assign(entity, obj)
			expect(manifest:maybeGet(entity, context.testComponent)).to.equal(obj)
		end)

	end)

	describe("multiGet", function()
		it("should return the specified components on the entity in order", function(context)
			local manifest = context.manifest
			local testComponent = context.testComponent
			local testComponent2 = manifest:define("test2", t.table)
			local testComponent3 = manifest:define("test3", t.table)
			local entity = manifest:create()
			local component1 = {}
			local component2 = {}
			local component3 = {}

			manifest.pools[testComponent]:assign(entity, component1)
			manifest.pools[testComponent2]:assign(entity, component2)
			manifest.pools[testComponent3]:assign(entity, component3)
		end)
	end)

	describe("add", function()
		it("should add a new component instance to the entity and return it", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local component = {}
			local obj = manifest:add(entity, context.testComponent, component)

			expect(manifest.pools[context.testComponent]:has(entity)).to.be.ok()
			expect(component).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment signal", function(context)
			local manifest = context.manifest
			local ranCallback

			manifest.pools[context.testComponent].onAdd:connect(function()
				ranCallback = true
			end)

			manifest:add(manifest:create(), context.testComponent, {})
			expect(ranCallback).to.equal(true)
		end)

		it("should return the correct component instance when a recycled entity is used", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest:destroy(entity)
			entity = manifest:create()

			expect(manifest:add(entity, context.testComponent, {}))
				.to.equal(manifest.pools[context.testComponent]:get(entity))
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

	describe("maybeAdd", function()
		it("should return nil if the component already exists on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest.pools[context.testComponent]:assign(entity, {})

			expect(manifest:maybeAdd(entity, context.testComponent)).to.equal(nil)
		end)

		it("should add a new component instance to the entity and return it if the component does not exist on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local component = {}
			local obj = manifest:maybeAdd(entity, context.testComponent, component)

			expect(manifest.pools[context.testComponent]:has(entity)).to.be.ok()
			expect(component).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment signal", function(context)
			local manifest = context.manifest
			local ranCallback

			manifest.pools[context.testComponent].onAdd:connect(function()
				ranCallback = true
			end)

			manifest:maybeAdd(manifest:create(), context.testComponent, {})
			expect(ranCallback).to.equal(true)
		end)

		it("should return the correct component instance when a recycled entity is used", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest:destroy(entity)
			entity = manifest:create()

			expect(manifest:maybeAdd(entity, context.testComponent, {}))
				.to.equal(manifest.pools[context.testComponent]:get(entity))
		end)

		it("should correctly handle tag components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local tag = manifest:define("tag", t.none)

			manifest:maybeAdd(entity, tag)

			expect(manifest.pools[tag]:has(entity)).to.be.ok()
			expect(manifest.pools[tag]:get(entity)).to.equal(nil)
		end)

	end)
	describe("multiAdd", function()
		it("should add all of the specified components to the entity then return the entity", function(context)
			local manifest = context.manifest
			local testComponent = context.testComponent
			local testComponent2 = manifest:define("test2", t.table)
			local testComponent3 = manifest:define("test3", t.table)
			local component1 = {}
			local component2 = {}
			local component3 = {}
			local entity = manifest:multiAdd(manifest:create(),
				testComponent, component1,
				testComponent2, component2,
				testComponent3, component3)

			expect(manifest.pools[testComponent]:get(entity, component1)).to.equal(component1)
			expect(manifest.pools[testComponent2]:get(entity, component2)).to.equal(component2)
			expect(manifest.pools[testComponent3]:get(entity, component3)).to.equal(component3)
		end)
	end)

	describe("getOrAdd", function()
		it("should add and return the component if the entity doesn't have it", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local obj = {}

			expect(manifest:getOrAdd(entity, context.testComponent, obj)).to.equal(obj)
		end)

		it("should return the component instance if the entity already has it", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local obj = manifest.pools[context.testComponent]:assign(entity, {})

			expect(manifest:getOrAdd(entity, context.testComponent, {})).to.equal(obj)
		end)

		it("should dispatch the component pool's added signal", function(context)
			local manifest =  context.manifest
			local ranCallback

			manifest.pools[context.testComponent].onAdd:connect(function()
				ranCallback = true
			end)

			manifest:getOrAdd(manifest:create(), context.testComponent, {})
			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("replace", function()
		it("should replace an existing component instance with a new one", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local obj = {}

			manifest.pools[context.testComponent]:assign(entity, {})
			expect(manifest:replace(entity, context.testComponent, obj)).to.equal(obj)
			expect(manifest.pools[context.testComponent]:get(entity)).to.equal(obj)
		end)

		it("should dispatch the component pool's update signal", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local ranCallback

			manifest.pools[context.testComponent].onUpdate:connect(function()
				ranCallback = true
			end)

			manifest.pools[context.testComponent]:assign(entity, {})
			manifest:replace(entity, context.testComponent, {})

			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("addOrReplace", function()
		it("should add the component if it does not exist on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local added = {}

			expect(manifest:addOrReplace(entity, context.testComponent, added)).to.equal(added)
			expect(manifest.pools[context.testComponent]:get(entity)).to.equal(added)
		end)

		it("should dispatch the component pool's added signal", function(context)
			local manifest = context.manifest
			local ranAddCallback

			manifest.pools[context.testComponent].onAdd:connect(function()
				ranAddCallback = true
			end)

			manifest:addOrReplace(manifest:create(), context.testComponent, {})
			expect(ranAddCallback).to.equal(true)
		end)

		it("should replace the component if it already exists on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local replaced = {}

			expect(manifest:addOrReplace(entity, context.testComponent, replaced)).to.equal(replaced)
			expect(manifest.pools[context.testComponent]:get(entity)).to.equal(replaced)
		end)

		it("should dispatch the component pool's replacement signal", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local ranReplaceCallback = false

			manifest.pools[context.testComponent].onUpdate:connect(function()
				ranReplaceCallback = true
			end)

			manifest.pools[context.testComponent]:assign(entity, {})
			manifest:addOrReplace(entity, context.testComponent, {})

			expect(ranReplaceCallback).to.equal(true)
		end)
	end)

	describe("remove", function()
		it("should remove a component that has been added to the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest.pools[context.testComponent]:assign(entity, {})
			manifest:remove(entity, context.testComponent)

			expect(manifest.pools[context.testComponent]:has(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local ranCallback

			manifest.pools[context.testComponent].onRemove:connect(function()
				ranCallback = true
			end)

			manifest.pools[context.testComponent]:assign(entity, {})
			manifest:remove(entity, context.testComponent)

			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("multiRemove", function()
		it("should remove all of the specified components from the entity and dispatch each components' removal signals", function(context)
			local manifest = context.manifest
			local testComponent = context.testComponent
			local testComponent2 = manifest:define("test2", t.table)
			local testComponent3 = manifest:define("test3", t.table)
			local entity = manifest:create()

			local component1 = manifest.pools[testComponent]:assign(entity, {})
			local component2 = manifest.pools[testComponent2]:assign(entity, {})
			local component3 = manifest.pools[testComponent3]:assign(entity, {})
			local component1ok = false
			local component2ok = false
			local component3ok = false

			manifest.pools[testComponent].onRemove:connect(function(e, component)
				expect(e).to.equal(entity)
				expect(component).to.equal(component1)
				component1ok = true
			end)

			manifest.pools[testComponent2].onRemove:connect(function(e, component)
				expect(e).to.equal(entity)
				expect(component).to.equal(component2)
				component2ok = true
			end)

			manifest.pools[testComponent3].onRemove:connect(function(e, component)
				expect(e).to.equal(entity)
				expect(component).to.equal(component3)
				component3ok = true
			end)

			manifest:multiRemove(entity, testComponent, testComponent2, testComponent3)

			expect(component1ok).to.equal(true)
			expect(component2ok).to.equal(true)
			expect(component3ok).to.equal(true)
			expect(manifest.pools[testComponent]:has(entity)).to.equal(nil)
			expect(manifest.pools[testComponent2]:has(entity)).to.equal(nil)
			expect(manifest.pools[testComponent3]:has(entity)).to.equal(nil)
		end)
	end)

	describe("maybeRemove", function()
		it("should return false if the component does not exist on the entity", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			expect(manifest:maybeRemove(entity, context.testComponent)).to.equal(false)
		end)

		it("should remove a component if it exists on the entity and return true", function(context)
			local manifest = context.manifest
			local entity = manifest:create()

			manifest.pools[context.testComponent]:assign(entity, {})
			expect(manifest:maybeRemove(entity, context.testComponent)).to.equal(true)

			expect(manifest.pools[context.testComponent]:has(entity)).to.equal(nil)
		end)

		it("should dispatch the component pool's removed signal", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local ranCallback

			manifest.pools[context.testComponent].onRemove:connect(function()
				ranCallback = true
			end)

			manifest.pools[context.testComponent]:assign(entity, {})
			manifest:maybeRemove(entity, context.testComponent)

			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("onAdded", function()
		it("should return the added signal for one specified component", function(context)
			local manifest = context.manifest

			expect(manifest:onAdded(context.testComponent))
				.to.equal(manifest.pools[context.testComponent].onAdd)
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

			expect(manifest:onRemoved(context.testComponent))
				.to.equal(manifest.pools[context.testComponent].onRemove)
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

			expect(manifest:onUpdated(context.testComponent))
				.to.equal(manifest.pools[context.testComponent].onUpdate)
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
				local id = bit32.band(entity, Constants.ENTITYID_MASK)

				expect(id).to.equal(bit32.band(manifest.entities[id], Constants.ENTITYID_MASK))
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

			expect(manifest:getPool(context.testComponent))
				.to.equal(manifest.pools[context.testComponent])
		end)
	end)
end

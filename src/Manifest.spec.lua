local Constants = require(script.Parent.Constants)
local Manifest = require(script.Parent.Manifest)

return function()
     beforeEach(function(context)
          local manifest = Manifest.new()

          context.manifest = manifest
          context.testComponent = manifest:define("table", "test")
     end)

	describe("new", function()
		it("should construct a new empty Manifest instance", function()
               local manifest = Manifest.new()

			expect(manifest.size).to.equal(0)
			expect(manifest.nextRecyclable).to.equal(Constants.NULL_ENTITYID)
			expect(#manifest.entities).to.equal(0)
			expect(#manifest.pools).to.equal(0)
			expect(#manifest.component).to.equal(0)
		end)
	end)

	describe("define", function()
		it("should generate a runtime identifier", function(context)
			expect(context.testComponent).to.be.ok()
			expect(typeof(context.testComponent)).to.equal("number")
		end)

		it("should create a valid component pool", function(context)
			expect(context.manifest.pools[context.testComponent]).to.be.ok()
		end)

		it("should return the component id", function(context)
			expect(context.testComponent).to.be.ok()
			expect(context.testComponent).to.be.a("number")
		end)
	end)

	describe("create", function()
		it("should return a valid entity identifier", function(context)
			local entity = context.manifest:create()

			expect(context.manifest:valid(entity)).to.equal(true)
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

               context.manifest:add(entity, context.testComponent, {})
               context.manifest:destroy(entity)

			expect(context.manifest:_getPool(context.testComponent):has(entity)).to.equal(nil)
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
                    [manifest:define(nil, "test1")] = true,
                    [manifest:define(nil, "test2")] = true,
                    [manifest:define(nil, "test3")] = true
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

               manifest:add(entity, manifest.component:named("test1"))
               manifest:add(entity, manifest.component:named("test2"))

			manifest:visit(function(component)
				expect(manifest:has(entity, component)).to.equal(true)
			end, entity)
		end)
	end)

	describe("has", function()
		it("should return false if the entity does not have the components", function(context)
               local manifest = context.manifest
               local entity = manifest:create()
			local testComponent2 = manifest:define(nil, "testComponent2")

			expect(manifest:has(entity, context.testComponent, testComponent2)).to.equal(false)
		end)

		it("should return true if the entity has the components", function(context)
               local manifest = context.manifest
               local entity = manifest:create()
			local testComponent2 = manifest:define(nil, "testComponent2")

			manifest:add(entity, context.testComponent, {})
			manifest:add(entity, testComponent2)
			expect(manifest:has(entity, context.testComponent, testComponent2)).to.equal(true)
		end)
	end)

	describe("any", function()
		it("should return false if the entity does not have any of the components", function(context)
			local manifest = context.manifest
               local entity = manifest:create()
			local testComponent2 = manifest:define(nil, "testComponent2")

			expect(manifest:any(entity, context.testComponent, testComponent2)).to.equal(false)
		end)

		it("should return true if the entity has any of the components", function(context)
			local manifest = context.manifest
               local entity = manifest:create()
			local testComponent2 = manifest:define(nil, "testComponent2")

			manifest:add(entity, testComponent2)

			expect(manifest:any(entity, context.testComponent, testComponent2)).to.equal(true)
		end)
	end)

	describe("get", function()
		it("should return nil if the entity does not have the component", function(context)
               local manifest = context.manifest
               local entity = manifest:create()

			expect(manifest:get(entity, context.testComponent)).to.never.be.ok()
		end)

		it("should return the component instance if the entity has the component", function(context)
               local manifest = context.manifest
               local entity = manifest:create()
               local obj = {}

			manifest:add(entity, context.testComponent, obj)
			expect(manifest:get(entity, context.testComponent)).to.equal(obj)
		end)
	end)

	describe("add", function()
		it("should add a new component instance to the entity and return it", function(context)
               local manifest = context.manifest
               local entity = manifest:create()
			local obj = manifest:add(entity, context.testComponent, {})

			expect(manifest:get(entity, context.testComponent)).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment listeners", function(context)
			local manifest = context.manifest
			local ranCallback

			manifest:addedSignal(context.testComponent):connect(function()
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
				.to.equal(manifest:get(entity, context.testComponent))
		end)

		it("should correctly handle tag components", function(context)
			local manifest = context.manifest
			local entity = manifest:create()
			local tag = manifest:define(nil, "tag")

			manifest:add(entity, tag)

               expect(manifest:has(entity, tag)).to.equal(true)
               expect(manifest:get(entity, tag)).to.equal(nil)
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
               local obj = manifest:add(entity, context.testComponent, {})

			expect(manifest:getOrAdd(entity, context.testComponent, {})).to.equal(obj)
		end)

		it("should dispatch the component pool's added listeners", function(context)
               local manifest =  context.manifest
               local ranCallback

               manifest:addedSignal(context.testComponent):connect(function()
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

			manifest:add(entity, context.testComponent, {})
			expect(manifest:replace(entity, context.testComponent, obj)).to.equal(obj)
			expect(manifest:get(entity, context.testComponent)).to.equal(obj)
		end)

		it("should dispatch the component pool's update listeners", function(context)
               local manifest = context.manifest
               local entity = manifest:create()
               local ranCallback

               manifest:updatedSignal(context.testComponent):connect(function()
                    ranCallback = true
               end)

               manifest:add(entity, context.testComponent, {})
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
			expect(manifest:get(entity, context.testComponent)).to.equal(added)
		end)

		it("should dispatch the component pool's added listeners", function(context)
               local manifest = context.manifest
               local ranAddCallback

               manifest:addedSignal(context.testComponent):connect(function()
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
			expect(manifest:get(entity, context.testComponent)).to.equal(replaced)
		end)

		it("should dispatch the component pool's replacement listeners", function(context)
               local manifest = context.manifest
               local entity = manifest:create()
               local ranReplaceCallback = false

               manifest:updatedSignal(context.testComponent):connect(function()
                    ranReplaceCallback = true
               end)

               manifest:add(entity, context.testComponent, {})
               manifest:addOrReplace(entity, context.testComponent, {})

			expect(ranReplaceCallback).to.equal(true)
		end)
	end)

	describe("remove", function()
		it("should remove a component that has been added to the entity", function(context)
               local manifest = context.manifest
               local entity = manifest:create()

			manifest:add(entity, context.testComponent, {})
			manifest:remove(entity, context.testComponent)

			expect(manifest:has(entity, context.testComponent)).to.equal(false)
		end)

		it("should dispatch the component pool's removed listeners", function(context)
               local manifest = context.manifest
               local entity = manifest:create()
               local ranCallback

               manifest:removedSignal(context.testComponent):connect(function()
                    ranCallback = true
               end)

               manifest:add(entity, context.testComponent, {})
			manifest:remove(entity, context.testComponent)

			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("addedSignal", function()
		it("should return the added signal for the specified component", function(context)
               local manifest = context.manifest

			expect(manifest:addedSignal(context.testComponent))
                    .to.equal(manifest.pools[context.testComponent].onAssign)
		end)
	end)

	describe("removedSignal", function()
		it("should return the removed signal for the specified component", function(context)
               local manifest = context.manifest

               expect(manifest:removedSignal(context.testComponent))
                    .to.equal(manifest.pools[context.testComponent].onRemove)
		end)
	end)

	describe("updatedSignal", function()
		it("should return the update signal for the specified component", function(context)
               local manifest = context.manifest

			expect(manifest:updatedSignal(context.testComponent))
                    .to.equal(manifest.pools[context.testComponent].onUpdate)
		end)
	end)

	describe("forEach", function()
		it("should iterate over all non-destroyed entities", function(context)
               local manifest = context.manifest
               local t = {}

               for i = 1, 128 do
                    t[i] = manifest:create()
               end

               for i, entity in ipairs(t) do
                    if i % 16 == 0 then
                         manifest:destroy(entity)
                    end
               end

               -- make some entities which will have incremented versions
               manifest:create()
               manifest:create()
               manifest:create()

			manifest:forEach(function(entity)
				local id = bit32.band(entity, Constants.ENTITYID_MASK)

				expect(id).to.equal(bit32.band(manifest.entities[id], Constants.ENTITYID_MASK))
			end)
		end)
	end)

	describe("numEntities", function()
		it("should return the number of non-destroyed entities currently in the manifest", function(context)
               local manifest = context.manifest
               local t = {}
               local num = 128

               for i = 1, num do
                    t[i] = manifest:create()
               end

               for i, entity in ipairs(t) do
                    if i % 16 == 0 then
                         num = num - 1
                         manifest:destroy(entity)
                    end
               end

			expect(manifest:numEntities()).to.equal(num)
		end)
	end)

	describe("getPool", function()
		it("should return the pool for the specified component type", function(context)
               local manifest = context.manifest

			expect(manifest:_getPool(context.testComponent))
                    .to.equal(manifest.pools[context.testComponent])
		end)
	end)
end

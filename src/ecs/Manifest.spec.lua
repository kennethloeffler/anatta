
local Constants = require(script.Parent.Constants)
local Manifest = require(script.Parent.Manifest)
local Pool = require(script.Parent.Pool)
local TestComponentType = "table"

local function defineTestComponent(manifest)
	return manifest:define("Test", TestComponentType)
end

return function()
	describe("new", function()
		local manifest = Manifest.new()

		it("should return a new empty entity system instance", function()
			expect(manifest.size).to.equal(0)
			expect(manifest.head).to.equal(0)
			expect(#manifest.entities).to.equal(0)
			expect(#manifest.pools).to.equal(0)
			expect(#manifest.component).to.equal(0)
		end)
	end)

	describe("define", function()
		local manifest = Manifest.new()
		local id = defineTestComponent(manifest)

		it("should generate a runtime identifier", function()
			expect(manifest.component.Test).to.be.ok()
			expect(typeof(manifest.component.Test)).to.equal("number")
		end)

		it("should create a valid component pool", function()
			expect(manifest.pools[manifest.component.Test]).to.be.ok()
		end)

		it("should return the component id", function()
			expect(id).to.be.ok()
			expect(id).to.be.a("number")
		end)
	end)

	describe("create", function()
		it("should return a valid entity identifier", function()
			local manifest = Manifest.new()
			local entity = manifest:create()

			expect(manifest:valid(entity)).to.equal(true)
		end)

		it("should recycle destroyed entity ids", function()
			local manifest = Manifest.new()
			local entity = manifest:create()
			local originalIdentifier = entity

			manifest:destroy(entity)
			entity = manifest:create()

			expect(bit32.band(entity, Constants.ENTITYID_MASK)).to.equal(bit32.band(originalIdentifier, Constants.ENTITYID_MASK))
			expect(bit32.rshift(entity, Constants.ENTITYID_WIDTH)).to.equal(bit32.rshift(originalIdentifier, Constants.ENTITYID_WIDTH) + 1)

			manifest:destroy(entity)
		end)
	end)

	describe("destroy", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local entityId = bit32.band(entity, Constants.ENTITYID_MASK)
		local originalVersion = bit32.rshift(entity, Constants.ENTITYID_WIDTH)
		local originalHead = manifest.head

		defineTestComponent(manifest)
		manifest:assign(entity, manifest.component.Test, {})
		manifest:destroy(entity)

		local newVersion = bit32.rshift(manifest.entities[entityId], Constants.ENTITYID_WIDTH)
		local ptr = bit32.band(manifest.entities[entityId], Constants.ENTITYID_WIDTH)

		it("should push the entity id onto the stack", function()
			expect(manifest.head).to.equal(entityId)
			expect(ptr).to.equal(originalHead)
		end)

		it("should increment the entity identifier's version", function()
			expect(originalVersion).to.equal(newVersion - 1)
		end)

		it("should remove all components that were on the entity", function()
			expect(Pool.has(manifest.pools[manifest.component.Test], entity)).to.never.be.ok()
		end)
	end)

	describe("valid", function()
		local manifest = Manifest.new()
		local entity = manifest:create()

		it("should return true if the entity identifier is valid", function()
			expect(manifest:valid(entity)).to.equal(true)
		end)

		it("should return false if the entity identifier is not valid", function()
			manifest:destroy(entity)
			expect(manifest:valid(entity)).to.equal(false)
		end)
	end)

	describe("stub", function()
		local manifest = Manifest.new()
		local entity = manifest:create()

		defineTestComponent(manifest)

		it("should return true if the entity has no components", function()
			expect(manifest:stub(entity)).to.equal(true)
		end)

		it("should return false if the entity has any components", function()
			manifest:assign(entity, manifest.component.Test, {})
			expect(manifest:stub(entity)).to.equal(false)
		end)
	end)

	describe("visit", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local types = {
			[manifest:define("test1")] = true,
			[manifest:define("test2")] = true,
			[manifest:define("test3")] = true
		}

		manifest:assign(entity, manifest.component.test1)
		manifest:assign(entity, manifest.component.test2)

		it("should return the component identifiers managed by the manifest", function()
			manifest:visit(function(component)
				expect(types[component]).to.be.ok()
			end)
		end)

		it("if passed an entity, should return the component identifiers which it has", function()
			manifest:visit(function(component)
				expect(manifest:has(entity, component)).to.equal(true)
			end, entity)
		end)
	end)

	describe("has", function()
		local manifest = Manifest.new()
		local entity = manifest:create()

		defineTestComponent(manifest)

		it("should return false if the entity does not have the component", function()
			expect(manifest:has(entity, manifest.component.Test)).to.equal(false)
		end)

		it("should return true if the entity has the component", function()
			manifest:assign(entity, manifest.component.Test, {})
			expect(manifest:has(entity, manifest.component.Test)).to.equal(true)
		end)
	end)

	describe("get", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local obj = {}

		defineTestComponent(manifest)

		it("should return nil if the entity does not have the component", function()
			expect(manifest:get(entity, manifest.component.Test)).to.never.be.ok()
		end)

		it("should return the component instance if the entity has the component", function()
			manifest:assign(entity, manifest.component.Test, obj)
			expect(manifest:get(entity, manifest.component.Test)).to.equal(obj)
		end)
	end)

	describe("assign", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local ranCallback = false

		defineTestComponent(manifest)

		manifest:assigned(manifest.component.Test):connect(function()
			ranCallback = true
		end)

		it("should assign a new component instance to the entity and return it", function()
			local obj = manifest:assign(entity, manifest.component.Test, {})

			expect(manifest:get(entity, manifest.component.Test)).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment listeners", function()
			expect(ranCallback).to.equal(true)
		end)

		it("should return the correct component instance when a recycled entity is used", function()
			manifest:destroy(entity)
			entity = manifest:create()

			expect(manifest:assign(entity, manifest.component.Test, {})).to.equal(manifest:get(entity, manifest.component.Test))
		end)
	end)

	describe("getOrAssign", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local obj = {}
		local ranCallback = false

		defineTestComponent(manifest)

		manifest:assigned(manifest.component.Test):connect(function()
			ranCallback = true
		end)

		it("should assign and return the component if the entity doesn't have it", function()
			expect(manifest:getOrAssign(entity, manifest.component.Test, obj)).to.equal(obj)
		end)

		it("should return the component instance if the entity already has it", function()
			expect(manifest:getOrAssign(entity, manifest.component.Test, obj)).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment listeners", function()
			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("replace", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local obj = {}
		local ranCallback = false

		defineTestComponent(manifest)

		manifest:updated(manifest.component.Test):connect(function()
			ranCallback = true
		end)

		it("should replace an existing component instance with a new one", function()
			manifest:assign(entity, manifest.component.Test, {})
			expect(manifest:replace(entity, manifest.component.Test, obj)).to.equal(obj)
			expect(manifest:get(entity, manifest.component.Test)).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment listeners", function()
			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("assignOrReplace", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local ranReplaceCallback = false
		local ranAssignCallback = false

		defineTestComponent(manifest)

		manifest:updated(manifest.component.Test):connect(function()
			ranReplaceCallback = true
		end)

		manifest:assigned(manifest.component.Test):connect(function()
			ranAssignCallback = true
		end)

		it("should assign the component if it does not exist on the entity", function()
			local assigned = {}

			expect(manifest:assignOrReplace(entity, manifest.component.Test, assigned)).to.equal(assigned)
			expect(manifest:get(entity, manifest.component.Test)).to.equal(assigned)
		end)

		it("should dispatch the component pool's assignment listeners", function()
			expect(ranAssignCallback).to.equal(true)
		end)

		it("should replace the component if it already exists on the entity", function()
			local replaced = {}

			expect(manifest:assignOrReplace(entity, manifest.component.Test, replaced)).to.equal(replaced)
			expect(manifest:get(entity, manifest.component.Test)).to.equal(replaced)
		end)

		it("should dispatch the component pool's replacement listeners", function()
			expect(ranReplaceCallback).to.equal(true)
		end)
	end)

	describe("remove", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local ranCallback = false

		defineTestComponent(manifest)

		manifest:removed(manifest.component.Test):connect(function()
			ranCallback = true
		end)

		it("should remove a component that has been assigned to the entity", function()
			manifest:assign(entity, manifest.component.Test, {})
			manifest:remove(entity, manifest.component.Test)

			expect(manifest:has(entity, manifest. component.Test)).to.equal(false)
		end)

		it("should dispatch the component pool's removed listeners", function()
			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("assigned", function()
		local manifest = Manifest.new()

		defineTestComponent(manifest)

		it("should return the assigned signal for the specified component", function()
			expect(manifest:assigned(manifest.component.Test)).to.equal(manifest.pools[manifest.component.Test].onAssign)
		end)
	end)

	describe("removed", function()
		local manifest = Manifest.new()

		defineTestComponent(manifest)

		it("should return the removed signal for the specified component", function()
			expect(manifest:removed(manifest.component.Test)).to.equal(manifest.pools[manifest.component.Test].onRemove)
		end)
	end)

	describe("updated", function()
		local manifest = Manifest.new()

		defineTestComponent(manifest)

		it("should return the updated signal for the specified component", function()
			expect(manifest:updated(manifest.component.Test)).to.equal(manifest.pools[manifest.component.Test].onUpdate)
		end)
	end)

	describe("view", function()
		local manifest = Manifest.new()
		local view = manifest:view({ defineTestComponent(manifest) })

		it("should return a new view instance", function()
			expect(view).to.be.ok()
			expect(view.componentPack).to.be.ok()
		end)
	end)

	describe("forEach", function()
		local manifest = Manifest.new()
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

		it("should iterate over all non-destroyed entities", function()
			manifest:forEach(function(entity)
				local id = bit32.band(entity, Constants.ENTITYID_MASK)

				expect(id).to.equal(bit32.band(manifest.entities[id], Constants.ENTITYID_MASK))
			end)
		end)
	end)

	describe("numEntities", function()
		local manifest = Manifest.new()
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

		it("should return the number of non-destroyed entities currently in the manifest", function()
			expect(manifest:numEntities()).to.equal(num)
		end)
	end)

	describe("getPool", function()
		local manifest = Manifest.new()

		defineTestComponent(manifest)

		it("should return the pool for the specified component type", function()
			expect(Manifest._getPool(manifest, manifest.component.Test)).to.equal(manifest.pools[manifest.component.Test])
		end)
	end)
end

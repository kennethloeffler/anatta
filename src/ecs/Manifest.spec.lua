local Identify = require(script.Parent.Parent.core.Identify)
local Constants = require(script.Parent.Parent.Constants)
local Manifest = require(script.Parent.Manifest)
local TestComponentType = "table"

local function defineTestComponent(manifest)
	Identify.Purge()
	manifest:DefineComponent("Test", TestComponentType)
end

return function()
	describe("new", function()
		local manifest = Manifest.new()

		it("should return a new empty entity system instance", function()
			expect(manifest.Size).to.equal(0)
			expect(manifest.Head).to.equal(0)
			expect(#manifest.Entities).to.equal(0)
			expect(#manifest.Pools).to.equal(0)
			expect(#manifest.Component).to.equal(0)
		end)
	end)

	describe("DefineComponent", function()
		local manifest = Manifest.new()

		defineTestComponent(manifest)

		it("should generate a runtime identifier", function()
			expect(manifest.Component.Test).to.be.ok()
			expect(typeof(manifest.Component.Test)).to.equal("number")
		end)

		it("should create a valid component pool", function()
			expect(manifest.Pools[manifest.Component.Test]).to.be.ok()
		end)
	end)

	describe("Create", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()
		local originalIdentifier = entity

		it("should return a valid entity identifier", function()
			expect(manifest:Valid(entity)).to.equal(true)
		end)

		it("should recycle destroyed entity ids", function()
			manifest:Destroy(entity)

			entity = manifest:Create()
			expect(bit32.band(entity, Constants.ENTITYID_MASK)).to.equal(originalIdentifier)

			manifest:Destroy(entity)
		end)
	end)

	describe("Destroy", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()
		local entityId = bit32.band(entity, Constants.ENTITYID_MASK)
		local originalVersion = bit32.rshift(entity, Constants.ENTITYID_WIDTH)
		local originalHead = manifest.Head

		manifest:Destroy(entity)

		local newVersion = bit32.rshift(manifest.Entities[entityId], Constants.ENTITYID_WIDTH)
		local ptr = bit32.band(manifest.Entities[entityId], Constants.ENTITYID_WIDTH)

		it("should push the entity id onto the stack", function()
			expect(manifest.Head).to.equal(entityId)
			expect(ptr).to.equal(originalHead)
		end)

		it("should increment the entity identifier's version", function()
			expect(originalVersion).to.equal(newVersion - 1)
		end)
	end)

	describe("Valid", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()

		it("should return true if the entity identifier is valid", function()
			expect(manifest:Valid(entity)).to.equal(true)
		end)

		it("should return false if the entity identifier is not valid", function()
			manifest:Destroy(entity)
			expect(manifest:Valid(entity)).to.equal(false)
		end)
	end)

	describe("Orphan", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()

		defineTestComponent(manifest)

		it("should return true if the entity has no components", function()
			expect(manifest:Orphan(entity)).to.equal(true)
		end)

		it("should return false if the entity has any components", function()
			manifest:Assign(entity, manifest.Component.Test, {})
			expect(manifest:Orphan(entity)).to.equal(false)
		end)
	end)

	describe("Has", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()

		defineTestComponent(manifest)

		it("should return false if the entity does not have the component", function()
			expect(manifest:Has(entity, manifest.Component.Test)).to.equal(false)
		end)

		it("should return true if the entity has the component", function()
			manifest:Assign(entity, manifest.Component.Test, {})
			expect(manifest:Has(entity, manifest.Component.Test)).to.equal(true)
		end)
	end)

	describe("Get", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()
		local obj = {}

		defineTestComponent(manifest)

		it("should return nil if the entity does not have the component", function()
			expect(manifest:Get(entity, manifest.Component.Test)).to.never.be.ok()
		end)

		it("should return the component instance if the entity has the component", function()
			manifest:Assign(entity, manifest.Component.Test, obj)
			expect(manifest:Get(entity, manifest.Component.Test)).to.equal(obj)
		end)
	end)

	describe("Assign", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()
		local obj = {}
		local ranCallback = false

		defineTestComponent(manifest)

		manifest:GetAssignedSignal(manifest.Component.Test):Connect(function()
			ranCallback = true
		end)

		it("should return a new component instance and assign it to the entity", function()
			expect(manifest:Assign(entity, manifest.Component.Test, obj)).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment listeners", function()
			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("GetOrAssign", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()
		local obj = {}
		local ranCallback = false

		defineTestComponent(manifest)

		manifest:GetAssignedSignal(manifest.Component.Test):Connect(function()
			ranCallback = true
		end)

		it("should assign and return the component if the entity doesn't have it", function()
			expect(manifest:GetOrAssign(entity, manifest.Component.Test, obj)).to.equal(obj)
		end)

		it("should return the component instance if the entity already has it", function()
			expect(manifest:GetOrAssign(entity, manifest.Component.Test, obj)).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment listeners", function()
			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("Replace", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()
		local obj = {}
		local ranCallback = false

		defineTestComponent(manifest)

		manifest:GetUpdatedSignal(manifest.Component.Test):Connect(function()
			ranCallback = true
		end)

		it("should replace an existing component instance with a new one", function()
			manifest:Assign(entity, manifest.Component.Test, {})
			expect(manifest:Replace(entity, manifest.Component.Test, obj)).to.equal(obj)
			expect(manifest:Get(entity, manifest.Component.Test)).to.equal(obj)
		end)

		it("should dispatch the component pool's assignment listeners", function()
			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("ReplaceOrAssign", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()
		local ranReplaceCallback = false
		local ranAssignCallback = false

		defineTestComponent(manifest)

		manifest:GetUpdatedSignal(manifest.Component.Test):Connect(function()
			ranReplaceCallback = true
		end)

		manifest:GetAssignedSignal(manifest.Component.Test):Connect(function()
			ranAssignCallback = true
		end)

		it("should assign the component if it does not exist on the entity", function()
			local assigned = {}

			expect(manifest:ReplaceOrAssign(entity, manifest.Component.Test, assigned)).to.equal(assigned)
			expect(manifest:Get(entity, manifest.Component.Test)).to.equal(assigned)
		end)

		it("should dispatch the component pool's assignment listeners", function()
			expect(ranAssignCallback).to.equal(true)
		end)

		it("should replace the component if it already exists on the entity", function()
			local replaced = {}

			expect(manifest:ReplaceOrAssign(entity, manifest.Component.Test, replaced)).to.equal(replaced)
			expect(manifest:Get(entity, manifest.Component.Test)).to.equal(replaced)
		end)

		it("should dispatch the component pool's replacement listeners", function()
			expect(ranReplaceCallback).to.equal(true)
		end)
	end)

	describe("Remove", function()
		local manifest = Manifest.new()
		local entity = manifest:Create()
		local ranCallback = false

		defineTestComponent(manifest)

		manifest:GetRemovedSignal(manifest.Component.Test):Connect(function()
			ranCallback = true
		end)

		it("should remove a component that has been assigned to the entity", function()
			manifest:Assign(entity, manifest.Component.Test, {})
			manifest:Remove(entity, manifest.Component.Test)

			expect(manifest:Has(entity, manifest. Component.Test)).to.equal(false)
		end)

		it("should dispatch the component pool's removed listeners", function()
			expect(ranCallback).to.equal(true)
		end)
	end)

	describe("GetAssignedSignal", function()
		local manifest = Manifest.new()

		defineTestComponent(manifest)

		it("should return the assigned signal for the specified component", function()
			expect(manifest:GetAssignedSignal(manifest.Component.Test)).to.equal(manifest.Pools[manifest.Component.Test].OnAssign)
		end)
	end)

	describe("GetRemovedSignal", function()
		local manifest = Manifest.new()

		defineTestComponent(manifest)

		it("should return the removed signal for the specified component", function()
			expect(manifest:GetRemovedSignal(manifest.Component.Test)).to.equal(manifest.Pools[manifest.Component.Test].OnRemove)
		end)
	end)

	describe("GetUpdatedSignal", function()
		local manifest = Manifest.new()

		defineTestComponent(manifest)

		it("should return the updated signal for the specified component", function()
			expect(manifest:GetUpdatedSignal(manifest.Component.Test)).to.equal(manifest.Pools[manifest.Component.Test].OnUpdate)
		end)
	end)

	describe("View", function()
	end)

	describe("getPool", function()
		local manifest = Manifest.new()

		defineTestComponent(manifest)

		it("should return the pool for the specified component type", function()
			expect(Manifest._getPool(manifest, manifest.Component.Test)).to.equal(manifest.Pools[manifest.Component.Test])
		end)
	end)
end
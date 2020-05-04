local View = require(script.Parent.View)
local Identify = require(script.Parent.Parent.core.Identify)
local Manifest = require(script.Parent.Manifest)
local manifest = Manifest.new()

Identify.Purge()

local Component1 = manifest:Define("Test1", "table")
local Component2 = manifest:Define("Test2", "table")
local Component3 = manifest:Define("Test3", "table")

local Pool1 = Manifest._getPool(manifest, Component1)
local Pool2 = Manifest._getPool(manifest, Component2)
local Pool3 = Manifest._getPool(manifest, Component3)

for i = 1, 100 do
	local entity = manifest:Create()

	if i % 2 == 0 then
		manifest:Assign(entity, Component1, {})
	end

	if i % 4 == 0 then
		manifest:Assign(entity, Component2, {})
	end

	if i % 8 == 0 then
		manifest:Assign(entity, Component3, {})
	end
end

return function()
	describe("new", function()
		it("should construct a single-component view when there is one included component and no excluded components", function()
			local view = View.new({ Pool1 })

			expect(getmetatable(view)).to.equal(View._singleMt)
			expect(view.Included).to.equal(Pool1)
			expect(view.Excluded).to.never.be.ok()
		end)

		it("should construct a single-component view with exclusion list when there is one included component and one or more excluded components", function()
			local view = View.new({ Pool1 }, { Pool3 })

			expect(getmetatable(view)).to.equal(View._singleWithExclMt)
			expect(view.Included).to.equal(Pool1)
			expect(view.Excluded[1]).to.equal(Pool3)
		end)

		it("should construct a multi-component view when there are multiple included components and no excluded components", function()
			local view = View.new({ Pool1, Pool2 })

			expect(getmetatable(view)).to.equal(View._multiMt)
			expect(view.Included[1]).to.equal(Pool1)
			expect(view.Included[2]).to.equal(Pool2)
			expect(view.Excluded).to.never.be.ok()
		end)

		it("should construct a multi-component view with exclusion list when there are multiple included components and one or more excluded components", function()
			local view = View.new({ Pool1, Pool2 }, { Pool3 })

			expect(getmetatable(view)).to.equal(View._multiWithExclMt)
			expect(view.Included[1]).to.equal(Pool1)
			expect(view.Included[2]).to.equal(Pool2)
			expect(view.Excluded[1]).to.equal(Pool3)
		end)
	end)

	describe("ForEach (multi-component)", function()
		local view = View.new( { Pool1, Pool2, Pool3 })
		local entitiesToIterate = {}

		it("should iterate all entities with at least the specified components", function()
			for _, entity in ipairs(Pool3.Internal) do
				if Pool1.External[entity] and Pool2.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEach(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)

		it("should pass component instances in the order given at the view's construction", function()
			entitiesToIterate = {}

			for _, entity in ipairs(Pool3.Internal) do
				if Pool1.External[entity] and Pool2.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEach(function(entity, first, second, third)
				expect(entitiesToIterate[entity]).to.be.ok()

				expect(manifest:Get(entity, Component1)).to.be.ok()
				expect(manifest:Get(entity, Component2)).to.be.ok()
				expect(manifest:Get(entity, Component3)).to.be.ok()

				expect(first).to.equal(manifest:Get(entity, Component1))
				expect(second).to.equal(manifest:Get(entity, Component2))
				expect(third).to.equal(manifest:Get(entity, Component3))
			end)
		end)
	end)

	describe("ForEachEntity (multi-component)", function()
		local view = View.new( { Pool1, Pool2, Pool3 })
		local entitiesToIterate = {}

		it("should iterate all entities with at least the specified components", function()
			for _, entity in ipairs(Pool3.Internal) do
				if Pool1.External[entity] and Pool2.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEach(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)
	end)

	describe("Has (multi-component)", function()
		local view = View.new( { Pool1, Pool2, Pool3 })

		it("should return true if the entity is iterated by the view", function()
			local entity = manifest:Create()

			manifest:Assign(entity, Component1, {})
			manifest:Assign(entity, Component2, {})
			manifest:Assign(entity, Component3, {})

			expect(view:Has(entity)).to.equal(true)
		end)

		it("should return false if the entity is not iterated by the view", function()
			local entity = manifest:Create()

			expect(view:Has(entity)).to.equal(false)
		end)
	end)

	describe("ForEach (single-component)", function()
		local view = View.new({ Pool1 })
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the specified component", function()
			for _, entity in ipairs(Pool1.Internal) do
				entitiesToIterate[entity] = true
			end

			view:ForEach(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)

		it("should pass the correct component instance", function()
			entitiesToIterate = {}

			for _, entity in ipairs(Pool1.Internal) do
				entitiesToIterate[entity] = true
			end

			view:ForEach(function(entity, component)
				expect(entitiesToIterate[entity]).to.be.ok()
				expect(manifest:Has(entity, Component1)).to.be.ok()
				expect(manifest:Get(entity, Component1)).to.equal(component)
			end)
		end)
	end)

	describe("ForEachEntity (single-component)", function()
		local view = View.new({ Pool1 })
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the specified component", function()
			for _, entity in ipairs(Pool1.Internal) do
				entitiesToIterate[entity] = true
			end

			view:ForEachEntity(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)
	end)

	describe("ForEachComponent (single-component)", function()
		local view = View.new({ Pool1 })

		it("should iterate all instances of the specified component", function()
			local index = 1

			view:ForEachComponent(function(component)
				expect(Pool1.Objects[index]).to.equal(component)
				index = index + 1
			end)
		end)
	end)

	describe("ForEach (multi-component with exlcusion list)", function()
		local view = View.new({ Pool2, Pool1 }, { Pool3 })
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the included components and none of the excluded components", function()
			for _, entity in ipairs(Pool2.Internal) do
				if Pool1.External[entity] and not Pool3.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEach(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)

		it("should pass component instances in the order given at the view's construction", function()
			entitiesToIterate = {}

			for _, entity in ipairs(Pool2.Internal) do
				if Pool1.External[entity] and not Pool3.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEach(function(entity, component2, component1)
				expect(entitiesToIterate[entity]).to.be.ok()

				expect(manifest:Get(entity, Component1)).to.be.ok()
				expect(manifest:Get(entity, Component2)).to.be.ok()

				expect(component1).to.equal(manifest:Get(entity, Component1))
				expect(component2).to.equal(manifest:Get(entity, Component2))
			end)
		end)
	end)

	describe("ForEachEntity (multi-component with exclusion list)", function()
		local view = View.new({ Pool1, Pool2 }, { Pool3 })
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the included components and none of the excluded components", function()
			for _, entity in ipairs(Pool2.Internal) do
				if Pool1.External[entity] and not Pool3.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEach(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)
	end)

	describe("Has (multi-component with exlcusion list)", function()
		local view = View.new({ Pool1, Pool2 }, { Pool3 })

		it("should return true if the entity is iterated by the view", function()
			local entity = manifest:Create()

			manifest:Assign(entity, Component1, {})
			manifest:Assign(entity, Component2, {})

			expect(view:Has(entity)).to.equal(true)
		end)

		it("should return false if the entity is not iterated by the view", function()
			local entity1 = manifest:Create()
			local entity2 = manifest:Create()

			manifest:Assign(entity1, Component1, {})
			manifest:Assign(entity1, Component2, {})
			manifest:Assign(entity1, Component3, {})

			manifest:Assign(entity2, Component2, {})
			manifest:Assign(entity2, Component3, {})

			expect(view:Has(entity1)).to.equal(false)
			expect(view:Has(entity2)).to.equal(false)
		end)
	end)

	describe("ForEach (single-component with exclusion list)", function()
		local view = View.new({ Pool1 }, { Pool2, Pool3 })
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the included component and none of the excluded components", function()
			for _, entity in ipairs(Pool1.Internal) do
				if not Pool2.External[entity] and not Pool3.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEach(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)

		it("should pass the correct component instance", function()
			entitiesToIterate = {}

			for _, entity in ipairs(Pool1.Internal) do
				if not Pool2.External[entity] and not Pool3.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEach(function(entity, component)
				expect(entitiesToIterate[entity]).to.be.ok()
				expect(manifest:Has(entity, Component1)).to.be.ok()
				expect(manifest:Get(entity, Component1)).to.equal(component)
			end)
		end)
	end)

	describe("ForEachEntity (single-component with exclusion list)", function()
		local view = View.new({ Pool1 }, { Pool2, Pool3 })
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the included component and none of the excluded components", function()
			for _, entity in ipairs(Pool1.Internal) do
				if not Pool2.External[entity] and not Pool3.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEachEntity(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)
	end)

	describe("ForEachComponent (single-component with exclusion list)", function()
		local view = View.new({ Pool1 }, { Pool2, Pool3 })
		local entitiesToIterate = {}

		it("should iterate all instances of the included component which do not belong to an entity with any of the excluded components", function()
			for _, entity in ipairs(Pool1.Internal) do
				if not Pool2.External[entity] and not Pool3.External[entity] then
					entitiesToIterate[entity] = true
				end
			end

			view:ForEachComponent(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)
	end)

	describe("selectShortestPool", function()
		it("should return the pool containing the fewest number of elements for the specified components", function()
			-- Pool3 is the shortest pool (see line 41)
			expect(View._selectShortestPool({ Pool1, Pool2, Pool3 })).to.equal(Pool3)
		end)
	end)

	describe("doesntHaveExcluded", function()
		it("should return true if the entity has none of the specified components", function()
			local entity = manifest:Create()

			manifest:Assign(entity, Component1, {})

			expect(View._doesntHaveExcluded(entity, { Pool2, Pool3 })).to.equal(true)
		end)

		it("should return false if the entity has any of the specified components", function()
			local entity = manifest:Create()

			manifest:Assign(entity, Component1, {})
			manifest:Assign(entity, Component3, {})

			expect(View._doesntHaveExcluded(entity, { Pool1, Pool3 })).to.equal(false)
		end)
	end)

	describe("hasIncluded", function()
		it("should return false if the entity doesn't have all of the specified components", function()
			local entity = manifest:Create()

			manifest:Assign(entity, Component1, {})
			manifest:Assign(entity, Component3, {})

			expect(View._hasIncluded(entity, { Pool1, Pool2 })).to.equal(false)
		end)

		it("should return true if the entity has all of the specified components", function()
			local entity = manifest:Create()

			manifest:Assign(entity, Component1, {})
			manifest:Assign(entity, Component2, {})
			manifest:Assign(entity, Component3, {})

			expect(View._hasIncluded(entity, { Pool1, Pool2, Pool3 })).to.equal(true)
		end)
	end)

	describe("hasIncludedThenPack", function()
		it("should return true and correctly populate the component pack if the entity has all of the specified components", function()
			local entity = manifest:Create()
			local componentPack = {}

			local first = manifest:Assign(entity, Component1, {})
			local second = manifest:Assign(entity, Component2, {})
			local third = manifest:Assign(entity, Component3, {})

			expect(View._hasIncludedThenPack(entity, { Pool1, Pool2, Pool3 }, componentPack)).to.equal(true)
			expect(componentPack[1]).to.equal(first)
			expect(componentPack[2]).to.equal(second)
			expect(componentPack[3]).to.equal(third)
		end)

		it("should return false if the entity doesn't have all of the specified components", function()
			local entity = manifest:Create()
			local componentPack = {}

			manifest:Assign(entity, Component1, {})
			manifest:Assign(entity, Component3, {})

			expect(View._hasIncludedThenPack(entity, { Pool1, Pool2, Pool3 }, componentPack)).to.equal(false)
		end)
	end)
end

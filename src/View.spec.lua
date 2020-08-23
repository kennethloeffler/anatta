local Constraint = require(script.Parent.Constraint)
local Manifest = require(script.Parent.Manifest)
local View = require(script.Parent.View)

return function()
	local manifest = Manifest.new()

	local Component1 = manifest:define("table", "Test1")
	local Component2 = manifest:define("table", "Test2")
	local Component3 = manifest:define("table", "Test3")
	local Tag = manifest:define(nil, "tagComponent")

	local TagPool = manifest:_getPool(Tag)
	local Pool1 = manifest:_getPool(Component1)
	local Pool2 = manifest:_getPool(Component2)
	local Pool3 = manifest:_getPool(Component3)

	for i = 1, 100 do
		local entity = manifest:create()

		if i % 2 == 0 then
			manifest:add(entity, Component1, {})
		end

		if i % 4 == 0 then
			manifest:add(entity, Component2, {})
		end

		if i % 8 == 0 then
			manifest:add(entity, Component3, {})
		end
	end

	describe("new", function()
		it("should construct a single-component view when there is one required component and no forbidden components", function()
			local view = View.new(Constraint.new(manifest, {Component1}))

			expect(getmetatable(view)).to.equal(View._singleMt)
			expect(view.required[1]).to.equal(Component1)
		end)

		it("should construct a single-component view with exclusion list when there is one required component and one or more forbidden components", function()
			local view = View.new(Constraint.new(manifest, {Component1}, {Component3}))

			expect(getmetatable(view)).to.equal(View._singleWithExclMt)
			expect(view.required[1]).to.equal(Component1)
			expect(view.forbidden[1]).to.equal(Component3)
		end)

		it("should construct a multi-component view when there are multiple required components and no forbidden components", function()
			local view = View.new(Constraint.new(manifest, {Component1, Component2}))

			expect(getmetatable(view)).to.equal(View._multiMt)
			expect(view.required[1]).to.equal(Component1)
			expect(view.required[2]).to.equal(Component2)
		end)

		it("should construct a multi-component view with exclusion list when there are multiple required components and one or more forbidden components", function()
			local view = View.new(Constraint.new(manifest, {Component1, Component2}, {Component3}))

			expect(getmetatable(view)).to.equal(View._multiWithExclMt)
			expect(view.required[1]).to.equal(Component1)
			expect(view.required[2]).to.equal(Component2)
			expect(view.forbidden[1]).to.equal(Component3)
		end)
	end)

	describe("each (multi-component)", function()
		local view = View.new(Constraint.new(manifest, {Component1, Component2, Component3}))
		local entitiesToIterate = {}

		it("should iterate all entities with at least the specified components", function()
			for _, entity in ipairs(Pool3.dense) do
				if Pool1:has(entity) and Pool2:has(entity) then
					entitiesToIterate[entity] = true
				end
			end

			view:each(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)

		it("should pass component instances in the order given at the view's construction", function()
			entitiesToIterate = {}

			for _, entity in ipairs(Pool3.dense) do
				if Pool1:has(entity) and Pool2:has(entity) then
					entitiesToIterate[entity] = true
				end
			end

			view:each(function(entity, first, second, third)
				expect(entitiesToIterate[entity]).to.be.ok()

				expect(manifest:get(entity, Component1)).to.be.ok()
				expect(manifest:get(entity, Component2)).to.be.ok()
				expect(manifest:get(entity, Component3)).to.be.ok()

				expect(first).to.equal(manifest:get(entity, Component1))
				expect(second).to.equal(manifest:get(entity, Component2))
				expect(third).to.equal(manifest:get(entity, Component3))
			end)
		end)
	end)

	describe("eachEntity (multi-component)", function()
		local view = View.new(Constraint.new(manifest, {Component1, Component2, Component3}))
		local entitiesToIterate = {}

		it("should iterate all entities with at least the specified components", function()
			for _, entity in ipairs(Pool3.dense) do
				if Pool1:has(entity) and Pool2:has(entity) then
					entitiesToIterate[entity] = true
				end
			end

			view:each(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)
	end)

	describe("has (multi-component)", function()
		local view = View.new(Constraint.new(manifest, {Component1, Component2, Component3}))

		it("should return true if the entity is iterated by the view", function()
			local entity = manifest:create()

			manifest:add(entity, Component1, {})
			manifest:add(entity, Component2, {})
			manifest:add(entity, Component3, {})

			expect(view:has(entity)).to.equal(true)
		end)

		it("should return false if the entity is not iterated by the view", function()
			local entity = manifest:create()

			expect(view:has(entity)).to.equal(false)
		end)
	end)

	describe("each (single-component)", function()
		local view = View.new(Constraint.new(manifest, {Component1, Component2, Component3}))
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the specified component", function()
			for _, entity in ipairs(Pool1.dense) do
				entitiesToIterate[entity] = true
			end

			view:each(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)

		it("should pass the correct component instance", function()
			entitiesToIterate = {}

			for _, entity in ipairs(Pool1.dense) do
				entitiesToIterate[entity] = true
			end

			view:each(function(entity, component)
				expect(entitiesToIterate[entity]).to.be.ok()
				expect(manifest:has(entity, Component1)).to.be.ok()
				expect(manifest:get(entity, Component1)).to.equal(component)
			end)
		end)
	end)

	describe("eachEntity (single-component)", function()
		local view = View.new(Constraint.new(manifest, {Component1}))
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the specified component", function()
			for _, entity in ipairs(Pool1.dense) do
				entitiesToIterate[entity] = true
			end

			view:eachEntity(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)
	end)

	describe("each (multi-component with exlcusion list)", function()
		local view = View.new(Constraint.new(manifest, {Component2, Component1}, {Component3}))
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the required components and none of the forbidden components", function()
			for _, entity in ipairs(Pool2.dense) do
				if Pool1:has(entity) and not Pool3:has(entity) then
					entitiesToIterate[entity] = true
				end
			end

			view:each(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)

		it("should pass component instances in the order given at the view's construction", function()
			entitiesToIterate = {}

			for _, entity in ipairs(Pool2.dense) do
				if Pool1:has(entity) and not Pool3:has(entity) then
					entitiesToIterate[entity] = true
				end
			end

			view:each(function(entity, component2, component1)
				expect(entitiesToIterate[entity]).to.be.ok()

				expect(manifest:get(entity, Component1)).to.be.ok()
				expect(manifest:get(entity, Component2)).to.be.ok()

				expect(component1).to.equal(manifest:get(entity, Component1))
				expect(component2).to.equal(manifest:get(entity, Component2))
			end)
		end)
	end)

	describe("eachEntity (multi-component with exclusion list)", function()
		local view = View.new(Constraint.new(manifest, {Component1, Component2}, {Component3}))
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the required components and none of the forbidden components", function()
			for _, entity in ipairs(Pool2.dense) do
				if Pool1:has(entity) and not Pool3:has(entity) then
					entitiesToIterate[entity] = true
				end
			end

			view:each(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)
	end)

	describe("has (multi-component with exclusion list)", function()
		local view = View.new(Constraint.new(manifest, {Component1, Component2}, {Component3}))

		it("should return true if the entity is iterated by the view", function()
			local entity = manifest:create()

			manifest:add(entity, Component1, {})
			manifest:add(entity, Component2, {})

			expect(view:has(entity)).to.equal(true)
		end)

		it("should return false if the entity is not iterated by the view", function()
			local entity1 = manifest:create()
			local entity2 = manifest:create()

			manifest:add(entity1, Component1, {})
			manifest:add(entity1, Component2, {})
			manifest:add(entity1, Component3, {})

			manifest:add(entity2, Component2, {})
			manifest:add(entity2, Component3, {})

			expect(view:has(entity1)).to.equal(false)
			expect(view:has(entity2)).to.equal(false)
		end)
	end)

	describe("each (single-component with exclusion list)", function()
		local view = View.new(Constraint.new(manifest, {Component1}, {Component3, Component2}))
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the required component and none of the forbidden components", function()
			for _, entity in ipairs(Pool1.dense) do
				if not Pool2:has(entity) and not Pool3:has(entity) then
					entitiesToIterate[entity] = true
				end
			end

			view:each(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)

		it("should pass the correct component instance", function()
			entitiesToIterate = {}

			for _, entity in ipairs(Pool1.dense) do
				if not Pool2:has(entity) and not Pool3:has(entity) then
					entitiesToIterate[entity] = true
				end
			end

			view:each(function(entity, component)
				expect(entitiesToIterate[entity]).to.be.ok()
				expect(manifest:has(entity, Component1)).to.be.ok()
				expect(manifest:get(entity, Component1)).to.equal(component)
			end)
		end)
	end)

	describe("eachEntity (single-component with exclusion list)", function()
		local view = View.new(Constraint.new(manifest, {Component1}, {Component3, Component2}))
		local entitiesToIterate = {}

		it("should iterate all the entities with at least the required component and none of the forbidden components", function()
			for _, entity in ipairs(Pool1.dense) do
				if not Pool2:has(entity) and not Pool3:has(entity) then
					entitiesToIterate[entity] = true
				end
			end

			view:eachEntity(function(entity)
				expect(entitiesToIterate[entity]).to.be.ok()
			end)
		end)
	end)

	describe("selectShortestPool", function()
		it("should return the pool containing the fewest number of elements for the specified components", function()
			-- Pool3 is the shortest pool (see line 41)
			expect(View._selectShortestPool(
				manifest, { Component1, Component2, Component3 })
			).to.equal(Pool3)
		end)
	end)
end

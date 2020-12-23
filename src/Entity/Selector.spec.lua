return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local Registry = require(script.Parent.Registry)
	local Selector = require(script.Parent.Selector)
	local SingleSelector = require(script.Parent.SingleSelector)
	local t = require(script.Parent.Parent.Core.TypeDefinition)

	local function makeEntities(registry)
		for i = 1, 100 do
			local entity = registry:create()

			if i % 2 == 0 then
				registry:add(entity, "Test1", {})
			end

			if i % 3 == 0 then
				registry:add(entity, "Test2", {})
			end

			if i % 4 == 0 then
				registry:add(entity, "Test3", {})
			end

			if i % 5 == 0 then
				registry:add(entity, "Test4", {})
			end
		end
	end

	beforeEach(function(context)
		local registry = Registry.new()

		registry:define("Test1", t.table)
		registry:define("Test2", t.table)
		registry:define("Test3", t.table)
		registry:define("Test4", t.table)
		context.registry = registry
	end)

	describe("new", function()
		it("should create a new Selector when there is anything more than one required component", function(context)
			local selector = Selector.new(context.registry, {
				required = { "Test1", "Test2" }
			})

			expect(getmetatable(selector)).to.equal(Selector)

			expect(selector._pool).to.be.ok()
			expect(getmetatable(selector._pool)).to.equal(Pool)

			expect(selector._updatedSet).to.be.a("table")
			expect(next(selector._updatedSet)).to.equal(nil)
		end)

		it("should create a new SingleSelector when there is exactly one required component and nothing else", function(context)
			local selector = Selector.new(context.registry, {
				required = { "Test1" }
			})

			expect(getmetatable(selector)).to.equal(SingleSelector)
		end)
	end)

	describe("entities", function()
		describe("required", function()
			it("should iterate all and only the entities with at least the required components", function(context)
				local toIterate = {}
				local registry = context.registry
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2", "Test3" }
				})

				selector:connect()
				makeEntities(registry)

				for _, entity in ipairs(registry._pools.Test1.dense) do
					if registry:has(entity, "Test2") and registry:has(entity, "Test3") then
						toIterate[entity] = true
					end
				end

				selector:entities(function(entity)
					expect(toIterate[entity]).to.equal(true)
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
			end)
		end)

		describe("required + forbidden", function()
			it("should iterate all and only the entities with at least the required components and none of the forbidden components", function(context)
				local toIterate = {}
				local registry = context.registry
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test3" }
				})

				selector:connect()
				makeEntities(registry)

				for _, entity in ipairs(registry._pools.Test1.dense) do
					if registry:has(entity, "Test2") and not registry:has(entity, "Test3") then
						toIterate[entity] = true
					end
				end

				selector:entities(function(entity)
					expect(toIterate[entity]).to.equal(true)
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
			end)
		end)

		describe("updated + required + forbidden", function()
			it("should iterate all and only the entities with at least the required components, none of the forbidden components, and all of the updated components", function(context)
				local toIterate = {}
				local registry = context.registry
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test4" },
					updated = { "Test3" }
				})

				selector:connect()
				makeEntities(registry)

				for _, entity in ipairs(registry._pools.Test1.dense) do
					if registry:has(entity, "Test2")
						and registry:has(entity, "Test3")
						and not registry:has(entity, "Test4")
					then
						toIterate[entity] = true
					end
				end

				local flipflop = true
				for entity in pairs(toIterate) do
					if flipflop then
						registry:replace(entity, "Test3", {})
						flipflop = false
					else
						toIterate[entity] = nil
						flipflop = true
					end
				end

				selector:entities(function(entity)
					expect(toIterate[entity]).to.equal(true)
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
			end)

			it("should capture updates caused during iteration", function(context)
				local toIterate = {}
				local registry = context.registry
				local selector = Selector.new(registry, {
					required = { "Test1" },
					updated = { "Test2" }
				})

				selector:connect()
				makeEntities(registry)

				selector:entities(function(entity)
					if registry:has(entity, "Test2") then
						registry:replace(entity, "Test2", {})
						toIterate[entity] = true
					end
				end)

				selector:entities(function(entity)
					expect(toIterate[entity]).to.equal(true)
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
			end)
		end)
	end)

	describe("each", function()
		describe("required", function()
			it("should iterate all and only the entities with at least the required components and pass their data", function(context)
				local toIterate = {}
				local registry = context.registry
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2", "Test3" }
				})

				selector:connect()
				makeEntities(registry)

				for _, entity in ipairs(registry._pools.Test1.dense) do
					if registry:has(entity, "Test2") and registry:has(entity, "Test3") then
						toIterate[entity] = true
					end
				end

				selector:each(function(entity, test1, test2, test3)
					expect(toIterate[entity]).to.equal(true)
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
					expect(test3).to.equal(registry:get(entity, "Test3"))
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
			end)
		end)

		describe("required + forbidden", function()
			it("should iterate all and only the entities with at least the required components and none of the forbidden components and pass their data", function(context)
				local toIterate = {}
				local registry = context.registry
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test3" }
				})

				selector:connect()
				makeEntities(registry)

				for _, entity in ipairs(registry._pools.Test1.dense) do
					if registry:has(entity, "Test2") and not registry:has(entity, "Test3") then
						toIterate[entity] = true
					end
				end

				selector:each(function(entity, test1, test2)
					expect(toIterate[entity]).to.equal(true)
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
			end)
		end)

		describe("updated + required + forbidden", function()
			it("should iterate all and only the entities with at least the required components, none of the forbidden components, and all of the updated components, and pass their data", function(context)
				local registry = context.registry
				local toIterate = {}
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test4" },
					updated = { "Test3" }
				})

				selector:connect()
				makeEntities(registry)

				for _, entity in ipairs(registry._pools.Test1.dense) do
					if
						registry:has(entity, "Test2")
						and registry:has(entity, "Test3")
						and not registry:has(entity, "Test4")
					then
						toIterate[entity] = true
					end
				end

				local flipflop = true
				for entity in pairs(toIterate) do
					if flipflop then
						toIterate[entity] = registry:get(entity, "Test3")
						registry:replace(entity, "Test3", {})
						flipflop = false
					else
						toIterate[entity] = nil
						flipflop = true
					end
				end

				selector:each(function(entity, test1, test2, test3)
					expect(toIterate[entity]).to.be.ok()
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
					expect(test3).to.equal(registry:get(entity, "Test3"))
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
			end)

			it("should capture updates caused during iteration", function(context)
				local toIterate = {}
				local registry = context.registry
				local selector = Selector.new(registry, {
					required = { "Test1" },
					updated = { "Test2" }
				})

				selector:connect()
				makeEntities(registry)

				selector:entities(function(entity)
					if registry:has(entity, "Test2") then
						toIterate[entity] = {}
						registry:replace(entity, "Test2", toIterate[entity])
					end
				end)

				selector:entities(function(entity, _, test2)
					expect(toIterate[entity]).to.equal(test2)
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
			end)
		end)
	end)

	describe("onAdded", function()
		describe("required", function()
			it("should call the callback when an entity with at least the required components is added", function(context)
				local registry = context.registry
				local called = false
				local testEntity = registry:create()
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2", "Test3" }
				})

				selector:connect()

				selector:onAdded(function(entity, test1, test2, test3)
					called = true
					expect(entity).to.equal(testEntity)
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
					expect(test3).to.equal(registry:get(entity, "Test3"))
				end)

				registry:multiAdd(testEntity,
					"Test1", {},
					"Test2", {},
					"Test3", {}
				)

				expect(called).to.equal(true)
				expect(selector._pool:contains(testEntity)).to.be.ok()
			end)
		end)

		describe("required + forbidden", function()
			it("should call the callback when an entity with at least the required components and none of the forbidden components is added", function(context)
				local registry = context.registry
				local called = false
				local testEntity = registry:create()
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test3" }
				})

				selector:connect()

				selector:onAdded(function(entity, test1, test2)
					called = true
					expect(entity).to.equal(testEntity)
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
				end)

				registry:multiAdd(testEntity,
					"Test1", {},
					"Test2", {}
				)

				expect(called).to.equal(true)
				expect(selector._pool:contains(testEntity)).to.be.ok()

				called = false
				registry:add(testEntity, "Test3", {})
				expect(called).to.equal(false)
				expect(selector._pool:contains(testEntity)).to.never.be.ok()
			end)
		end)

		describe("updated + required + forbidden", function()
			it("should call the callback when an entity with at least the required components, none of the forbidden components, and all of the updated components is added", function(context)
				local registry = context.registry
				local testEntity = registry:create()
				local called = false
				local selector = Selector.new(registry, {
					required = { "Test1" },
					updated = { "Test2", "Test4" },
					forbidden = { "Test3" }
				})

				selector:connect()

				selector:onAdded(function(entity, test1, test2, test4)
					called = true
					expect(entity).to.equal(testEntity)
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
					expect(test4).to.equal(registry:get(entity, "Test4"))
				end)

				registry:multiAdd(testEntity,
					"Test1", {},
					"Test2", {},
					"Test4", {}
				)

				expect(called).to.equal(false)

				registry:replace(testEntity, "Test4", {})
				registry:replace(testEntity, "Test2", {})
				expect(called).to.equal(true)
				expect(selector._pool:contains(testEntity)).to.be.ok()

				called = false
				registry:add(testEntity, "Test3", {})
				expect(selector._pool:contains(testEntity)).to.never.be.ok()

				registry:replace(testEntity, "Test4", {})
				registry:replace(testEntity, "Test2", {})
				expect(called).to.equal(false)
				expect(selector._pool:contains(testEntity)).to.never.be.ok()
			end)

			it("should not fire twice when a component is updated twice", function(context)
				local registry = context.registry
				local called = false
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2" },
					updated = { "Test4" },
				})

				selector:connect()

				selector:onAdded(function()
					called = not called
				end)

				local testEntity = registry:create()

				registry:multiAdd(testEntity,
					"Test1", {},
					"Test2", {},
					"Test4", {}
				)

				registry:replace(testEntity, "Test4", {})
				registry:replace(testEntity, "Test4", {})
				expect(called).to.equal(true)
			end)
		end)
	end)

	describe("onRemoved", function()
		describe("required", function()
			it("should call the callback when an entity with at least the required components is untracked", function(context)
				local registry = context.registry
				local called = false
				local testEntity = registry:create()
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2", "Test3" }
				})

				selector:connect()

				selector:onRemoved(function(entity, test1, test2, test3)
					called = true
					expect(entity).to.equal(testEntity)
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
					expect(test3).to.equal(registry:get(entity, "Test3"))
				end)

				registry:multiAdd(testEntity,
					"Test1", {},
					"Test2", {},
					"Test3", {}
				)

				registry:remove(testEntity, "Test2")
				expect(called).to.equal(true)
				expect(selector._pool:contains(testEntity)).to.never.be.ok()
			end)
		end)

		describe("required + forbidden", function()
			it("should call the callback when an entity with at least the required components and none of the forbidden components is untracked", function(context)
				local registry = context.registry
				local called = false
				local testEntity = registry:create()
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test3" }
				})

				selector:connect()

				selector:onRemoved(function(entity, test1, test2)
					called = true
					expect(entity).to.equal(testEntity)
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
				end)

				registry:multiAdd(testEntity,
					"Test1", {},
					"Test2", {}
				)

				registry:add(testEntity, "Test3", {})
				expect(called).to.equal(true)
				expect(selector._pool:contains(testEntity)).to.never.be.ok()
			end)
		end)

		describe("updated + required + forbidden", function()
			it("should call the callback when an entity with at least the required components, none of the forbidden components, and all of the updated components is untracked", function(context)
				local registry = context.registry
				local called = false
				local testEntity = registry:create()
				local selector = Selector.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test3" },
					updated = { "Test4" }
				})

				selector:connect()

				selector:onRemoved(function(entity, test1, test2, test4)
					called = true
					expect(entity).to.equal(testEntity)
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
					expect(test4).to.equal(registry:get(entity, "Test4"))
				end)

				registry:multiAdd(testEntity,
					"Test1", {},
					"Test2", {},
					"Test4", {}
				)

				registry:replace(testEntity, "Test4", {})
				registry:remove(testEntity, "Test2", {})
				expect(selector._pool:contains(testEntity)).to.never.be.ok()
				expect(called).to.equal(true)
			end)
		end)

		it("should stop tracking updates on an entity after all updated components have been removed", function(context)
			local registry = context.registry
			local selector = Selector.new(registry, {
				required = { "Test1", "Test2" },
				forbidden = { "Test3" },
				updated = { "Test4" }
			})

			selector:connect()

			local testEntity = registry:create()

			registry:multiAdd(testEntity,
				"Test1", {},
				"Test2", {},
				"Test4", {}
			)

			registry:replace(testEntity, "Test4", {})
			registry:remove(testEntity, "Test4")
			expect(selector._pool:contains(testEntity)).to.never.be.ok()
			expect(selector._updatedSet[testEntity]).to.equal(nil)
		end)
	end)

	describe("_getShortestRequiredPool", function()
		it("should select the pool with the least number of components in it", function(context)
			local selector = Selector.new(context.registry, {
				required = { "Test1", "Test4" }
			})

			selector:connect()
			makeEntities(context.registry)

			expect(selector:_getShortestRequiredPool()).to.equal(context.registry._pools.Test4)
		end)
	end)

	describe("_pack", function()
		it("should pack the required and updated components of the entity into _packed", function(context)
			local selector = Selector.new(context.registry, {
				required = { "Test2", "Test3" },
				updated = { "Test3", "Test4" }
			})
			local entity = context.registry:multiAdd(context.registry:create(),
				"Test1", {},
				"Test2", {},
				"Test3", {},
				"Test4", {}
			)

			selector:_pack(entity)

			expect(selector._packed[1]).to.equal(context.registry:get(entity, "Test2"))
			expect(selector._packed[2]).to.equal(context.registry:get(entity, "Test3"))
			expect(selector._packed[3]).to.equal(context.registry:get(entity, "Test3"))
			expect(selector._packed[4]).to.equal(context.registry:get(entity, "Test4"))
		end)
	end)

	describe("_try", function()
		it("should return true if the entity has all required components and no forbidden components", function(context)
			local registry = context.registry
			local selector = Selector.new(registry, {
				required = { "Test2", "Test2" },
				forbidden = { "Test3" }
			})

			expect(selector:_try(registry:multiAdd(registry:create(),
				"Test1", {},
				"Test2", {}
		))).to.equal(true)
		end)

		it("should return false if the entity has does not all required components or any forbidden components", function(context)
			local registry = context.registry
			local selector = Selector.new(registry, {
				required = { "Test2", "Test2" },
				forbidden = { "Test3" }
			})

			expect(selector:_try(registry:multiAdd(registry:create(),
				"Test1", {}
			))).to.equal(false)

			expect(selector:_try(registry:multiAdd(registry:create(),
				"Test1", {},
				"Test2", {},
				"Test3", {}
			))).to.equal(false)
		end)
	end)

	describe("_tryPack", function()
		it("should pack the required components and return true if the entity has all of them", function(context)
			local registry = context.registry
			local selector = Selector.new(registry, {
				required = { "Test1", "Test2" },
				forbidden = { "Test3" }
			})
			local entity = registry:multiAdd(registry:create(),
				"Test1", {},
				"Test2", {}
			)

			expect(selector:_tryPack(entity)).to.equal(true)

			expect(selector._packed[1]).to.equal(registry:get(entity, "Test1"))
			expect(selector._packed[2]).to.equal(registry:get(entity, "Test2"))
			expect(selector._packed[3]).to.equal(nil)

			expect(selector:_tryPack(registry:multiAdd(registry:create(),
				"Test1", {},
				"Test2", {},
				"Test3", {}
			))).to.equal(false)
		end)
	end)
end

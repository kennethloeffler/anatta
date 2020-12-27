return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local Registry = require(script.Parent.Registry)
	local Collection = require(script.Parent.Collection)
	local SingleCollection = require(script.Parent.SingleCollection)
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
		it("should create a new Collection when there is anything more than one required component", function(context)
			local collection = Collection.new(context.registry, {
				required = { "Test1", "Test2" }
			})

			expect(getmetatable(collection)).to.equal(Collection)

			expect(collection._pool).to.be.ok()
			expect(getmetatable(collection._pool)).to.equal(Pool)

			expect(collection._updatedSet).to.be.a("table")
			expect(next(collection._updatedSet)).to.equal(nil)
		end)

		it("should create a new SingleCollection when there is exactly one required component and nothing else", function(context)
			local collection = Collection.new(context.registry, {
				required = { "Test1" }
			})

			expect(getmetatable(collection)).to.equal(SingleCollection)
		end)

		it("should populate _required, _updated, and _forbidden", function(context)
			local registry = context.registry
			local collection = Collection.new(registry, {
				required = { "Test1", "Test2" },
				updated = { "Test3" },
				forbidden = { "Test4" },
			})

			expect(collection._required[1]).to.equal(registry._pools.Test1)
			expect(collection._required[2]).to.equal(registry._pools.Test2)
			expect(collection._updated[1]).to.equal(registry._pools.Test3)
			expect(collection._forbidden[1]).to.equal(registry._pools.Test4)
		end)

		it("should populate the full update bitset", function(context)
			local registry = context.registry
			local collection = Collection.new(registry, {
				updated = { "Test1", "Test2", "Test3" },
			})

			expect(collection._allUpdatedSet).to.equal(bit32.rshift(0xFFFFFFFF, 29))
		end)
	end)

	describe("connect", function()
		it("should connect the collection to the component pools", function(context)
			local registry = context.registry
			local collection = Collection.new(registry, {
				required = { "Test1" },
				updated = { "Test2" },
				forbidden = { "Test3" },
			})

			expect(collection._required[1].onAdd._callbacks[1]).to.be.ok()
			expect(collection._required[1].onRemove._callbacks[1]).to.be.ok()

			expect(collection._forbidden[1].onRemove._callbacks[1]).to.be.ok()
			expect(collection._forbidden[1].onAdd._callbacks[1]).to.be.ok()

			expect(collection._updated[1].onUpdate._callbacks[1]).to.be.ok()
			expect(collection._updated[1].onRemove._callbacks[1]).to.be.ok()
		end)
	end)

	describe("each", function()
		describe("required", function()
			it("should iterate all and only the entities with at least the required components and pass their data", function(context)
				local toIterate = {}
				local registry = context.registry
				local collection = Collection.new(registry, {
					required = { "Test1", "Test2", "Test3" }
				})

				makeEntities(registry)

				for _, entity in ipairs(registry._pools.Test1.dense) do
					if registry:has(entity, "Test2") and registry:has(entity, "Test3") then
						toIterate[entity] = true
					end
				end

				collection:each(function(entity, test1, test2, test3)
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
				local collection = Collection.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test3" }
				})

				makeEntities(registry)

				for _, entity in ipairs(registry._pools.Test1.dense) do
					if registry:has(entity, "Test2") and not registry:has(entity, "Test3") then
						toIterate[entity] = true
					end
				end

				collection:each(function(entity, test1, test2)
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
				local collection = Collection.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test4" },
					updated = { "Test3" }
				})

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

				collection:each(function(entity, test1, test2, test3)
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
				local collection = Collection.new(registry, {
					required = { "Test1" },
					updated = { "Test2" }
				})

				makeEntities(registry)

				collection:each(function(entity)
					if registry:has(entity, "Test2") then
						toIterate[entity] = {}
						registry:replace(entity, "Test2", toIterate[entity])
					end
				end)

				collection:each(function(entity, _, test2)
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
				local collection = Collection.new(registry, {
					required = { "Test1", "Test2", "Test3" }
				})

				collection:onAdded(function(entity, test1, test2, test3)
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
				expect(collection._pool:getIndex(testEntity)).to.be.ok()
			end)
		end)

		describe("required + forbidden", function()
			it("should call the callback when an entity with at least the required components and none of the forbidden components is added", function(context)
				local registry = context.registry
				local called = false
				local testEntity = registry:create()
				local collection = Collection.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test3" }
				})

				collection:onAdded(function(entity, test1, test2)
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
				expect(collection._pool:getIndex(testEntity)).to.be.ok()

				called = false
				registry:add(testEntity, "Test3", {})
				expect(called).to.equal(false)
				expect(collection._pool:getIndex(testEntity)).to.never.be.ok()
			end)
		end)

		describe("updated + required + forbidden", function()
			it("should call the callback when an entity with at least the required components, none of the forbidden components, and all of the updated components is added", function(context)
				local registry = context.registry
				local testEntity = registry:create()
				local called = false
				local collection = Collection.new(registry, {
					required = { "Test1" },
					updated = { "Test2", "Test4" },
					forbidden = { "Test3" }
				})

				collection:onAdded(function(entity, test1, test2, test4)
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
				expect(collection._pool:getIndex(testEntity)).to.be.ok()

				called = false
				registry:add(testEntity, "Test3", {})
				expect(collection._pool:getIndex(testEntity)).to.never.be.ok()

				registry:replace(testEntity, "Test4", {})
				registry:replace(testEntity, "Test2", {})
				expect(called).to.equal(false)
				expect(collection._pool:getIndex(testEntity)).to.never.be.ok()
			end)

			it("should not fire twice when a component is updated twice", function(context)
				local registry = context.registry
				local called = false
				local collection = Collection.new(registry, {
					required = { "Test1", "Test2" },
					updated = { "Test4" },
				})

				collection:onAdded(function()
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
				local collection = Collection.new(registry, {
					required = { "Test1", "Test2", "Test3" }
				})

				collection:onRemoved(function(entity, test1, test2, test3)
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
				expect(collection._pool:getIndex(testEntity)).to.never.be.ok()
			end)
		end)

		describe("required + forbidden", function()
			it("should call the callback when an entity with at least the required components and none of the forbidden components is untracked", function(context)
				local registry = context.registry
				local called = false
				local testEntity = registry:create()
				local collection = Collection.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test3" }
				})

				collection:onRemoved(function(entity, test1, test2)
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
				expect(collection._pool:getIndex(testEntity)).to.never.be.ok()
			end)
		end)

		describe("updated + required + forbidden", function()
			it("should call the callback when an entity with at least the required components, none of the forbidden components, and all of the updated components is untracked", function(context)
				local registry = context.registry
				local called = false
				local testEntity = registry:create()
				local collection = Collection.new(registry, {
					required = { "Test1", "Test2" },
					forbidden = { "Test3" },
					updated = { "Test4" }
				})

				collection:onRemoved(function(entity, test1, test2, test4)
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
				expect(collection._pool:getIndex(testEntity)).to.never.be.ok()
				expect(called).to.equal(true)
			end)
		end)

		it("should stop tracking updates on an entity after all updated components have been removed", function(context)
			local registry = context.registry
			local collection = Collection.new(registry, {
				required = { "Test1", "Test2" },
				forbidden = { "Test3" },
				updated = { "Test4" }
			})

			local testEntity = registry:create()

			registry:multiAdd(testEntity,
				"Test1", {},
				"Test2", {},
				"Test4", {}
			)

			registry:replace(testEntity, "Test4", {})
			registry:remove(testEntity, "Test4")
			expect(collection._pool:getIndex(testEntity)).to.never.be.ok()
			expect(collection._updatedSet[testEntity]).to.equal(nil)
		end)
	end)

	describe("_getShortestRequiredPool", function()
		it("should select the pool with the least number of components in it", function(context)
			local collection = Collection.new(context.registry, {
				required = { "Test1", "Test4" }
			})

			makeEntities(context.registry)

			expect(collection:_getShortestRequiredPool()).to.equal(context.registry._pools.Test4)
		end)
	end)

	describe("_pack", function()
		it("should pack the required and updated components of the entity into _packed", function(context)
			local collection = Collection.new(context.registry, {
				required = { "Test2", "Test3" },
				updated = { "Test3", "Test4" }
			})
			local entity = context.registry:multiAdd(context.registry:create(),
				"Test1", {},
				"Test2", {},
				"Test3", {},
				"Test4", {}
			)

			collection:_pack(entity)

			expect(collection._packed[1]).to.equal(context.registry:get(entity, "Test2"))
			expect(collection._packed[2]).to.equal(context.registry:get(entity, "Test3"))
			expect(collection._packed[3]).to.equal(context.registry:get(entity, "Test3"))
			expect(collection._packed[4]).to.equal(context.registry:get(entity, "Test4"))
		end)
	end)

	describe("_tryPack", function()
		it("should pack the required components and return true if the entity has all of them", function(context)
			local registry = context.registry
			local collection = Collection.new(registry, {
				required = { "Test1", "Test2" },
				forbidden = { "Test3" }
			})
			local entity = registry:multiAdd(registry:create(),
				"Test1", {},
				"Test2", {}
			)

			expect(collection:_tryPack(entity)).to.equal(true)

			expect(collection._packed[1]).to.equal(registry:get(entity, "Test1"))
			expect(collection._packed[2]).to.equal(registry:get(entity, "Test2"))
			expect(collection._packed[3]).to.equal(nil)

			expect(collection:_tryPack(registry:multiAdd(registry:create(),
				"Test1", {},
				"Test2", {},
				"Test3", {}
			))).to.equal(false)
		end)
	end)
end

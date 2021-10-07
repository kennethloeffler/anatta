return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local Registry = require(script.Parent.Registry)
	local Reactor = require(script.Parent.Reactor)
	local SingleReactor = require(script.Parent.SingleReactor)
	local t = require(script.Parent.Parent.Core.TypeDefinition)

	beforeEach(function(context)
		local registry = Registry.new()

		registry:defineComponent({
			name = "Test1",
			type = t.table,
		})

		registry:defineComponent({
			name = "Test2",
			type = t.table,
		})

		registry:defineComponent({
			name = "Test3",
			type = t.table,
		})

		registry:defineComponent({
			name = "Test4",
			type = t.table,
		})

		registry:defineComponent({
			name = "TestTag",
			type = t.none,
		})

		context.registry = registry
	end)

	local function createTestReactor(registry, query, callback)
		local len = 0
		local toIterate = {}
		local reactor = Reactor.new(registry, query)

		if callback then
			reactor:withAttachments(callback)
		end

		for i = 1, 100 do
			local entity = registry:createEntity()

			if i % 2 == 0 then
				registry:addComponent(entity, "Test1", {})
				registry:addComponent(entity, "TestTag")
			end

			if i % 3 == 0 then
				registry:addComponent(entity, "Test2", {})
			end

			if i % 4 == 0 then
				registry:addComponent(entity, "Test3", {})
			end

			if i % 5 == 0 then
				registry:addComponent(entity, "Test4", {})
			end

			if
				registry:entityHas(entity, unpack(query.withAll or {}))
				and not registry:entityHasAny(entity, unpack(query.without or {}))
				and registry:entityHas(entity, unpack(query.withUpdated or {}))
			then
				len += 1

				if query.withUpdated and next(query.withUpdated) then
					for _, component in ipairs(query.withUpdated) do
						registry:replaceComponent(entity, component, {})
					end

					toIterate[entity] = registry:getComponents(
						entity,
						{},
						unpack(query.withUpdated or {})
					)
				else
					toIterate[entity] = true
				end
			end
		end

		return reactor, toIterate, len
	end

	describe("new", function()
		it(
			"should create a new Reactor when there is anything more than one required component",
			function(context)
				local reactor = Reactor.new(context.registry, {
					withAll = { "Test1", "Test2" },
				})

				expect(getmetatable(reactor)).to.equal(Reactor)

				expect(reactor._pool).to.be.ok()
				expect(getmetatable(reactor._pool)).to.equal(Pool)

				expect(reactor._updates).to.be.a("table")
				expect(next(reactor._updates)).to.equal(nil)
			end
		)

		it(
			"should create a new SingleReactor when there is exactly one required component and nothing else",
			function(context)
				local reactor = Reactor.new(context.registry, {
					withAll = { "Test1" },
				})

				expect(getmetatable(reactor)).to.equal(SingleReactor)
			end
		)

		it("should populate _required, _updated, and _forbidden", function(context)
			local registry = context.registry
			local reactor = Reactor.new(context.registry, {
				withAll = { "Test1", "Test2" },
				withUpdated = { "Test3" },
				without = { "Test4" },
			})

			expect(reactor._required[1]).to.equal(registry._pools.Test1)
			expect(reactor._required[2]).to.equal(registry._pools.Test2)
			expect(reactor._updated[1]).to.equal(registry._pools.Test3)
			expect(reactor._forbidden[1]).to.equal(registry._pools.Test4)
		end)

		it("should correctly instantiate the full update bitset", function(context)
			local reactor = Reactor.new(context.registry, {
				withAll = { "Test1" },
				withUpdated = { "Test1", "Test2", "Test3" },
			})

			expect(reactor._allUpdates).to.equal(bit32.rshift(0xFFFFFFFF, 29))
		end)
	end)

	describe("each", function()
		describe("required", function()
			it(
				"should iterate all and only the entities with at least the required components and pass their data",
				function(context)
					local registry = context.registry
					local reactor, toIterate = createTestReactor(registry, {
						withAll = { "Test1", "Test2", "Test3" },
					})

					reactor:each(function(entity, test1, test2, test3)
						expect(toIterate[entity]).to.equal(true)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						expect(test3).to.equal(registry:getComponent(entity, "Test3"))
						toIterate[entity] = nil
					end)

					expect(next(toIterate)).to.equal(nil)
				end
			)
		end)

		describe("required + optional", function()
			it(
				"should iterate all the entities with at least the required components and any of the optional components",
				function(context)
					local registry = context.registry
					local reactor, toIterate = createTestReactor(registry, {
						withAll = { "Test1", "Test2" },
						withAny = { "TestTag", "Test4" },
						without = {},
					})

					reactor:each(function(entity, test1, test2, test5)
						expect(toIterate[entity]).to.equal(true)
						toIterate[entity] = nil

						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						expect(test5).to.equal(nil)
					end)

					expect(next(toIterate)).to.equal(nil)
				end
			)
		end)

		describe("required + forbidden", function()
			it(
				"should iterate all and only the entities with at least the required components and none of the forbidden components and pass their data",
				function(context)
					local registry = context.registry
					local reactor, toIterate = createTestReactor(registry, {
						withAll = { "Test1", "Test2" },
						without = { "Test3" },
					})

					reactor:each(function(entity, test1, test2)
						expect(toIterate[entity]).to.equal(true)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						toIterate[entity] = nil
					end)

					expect(next(toIterate)).to.equal(nil)
				end
			)
		end)

		describe("updated + required + forbidden", function()
			it(
				"should iterate all and only the entities with at least the required components, none of the forbidden components, and all of the updated components, and pass their data",
				function(context)
					local registry = context.registry
					local reactor, toIterate = createTestReactor(registry, {
						withAll = { "Test1" },
						withUpdated = { "Test2", "Test3" },
						without = { "Test4" },
					})

					reactor:each(function(entity, test1, test2, test3)
						expect(toIterate[entity]).to.be.ok()
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						expect(test3).to.equal(registry:getComponent(entity, "Test3"))
						toIterate[entity] = nil
					end)

					expect(next(toIterate)).to.equal(nil)
				end
			)

			it("should capture updates caused during iteration", function(context)
				local registry = context.registry
				local reactor, toIterate = createTestReactor(registry, {
					withAll = { "Test1" },
					withUpdated = { "Test2" },
				})

				reactor:each(function(entity)
					toIterate[entity] = registry:replaceComponent(entity, "Test2", {})
				end)

				expect(next(toIterate)).to.be.ok()

				reactor:each(function(entity, _, test2)
					expect(toIterate[entity]).to.equal(test2)
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
			end)
		end)
	end)

	describe("added", function()
		describe("required", function()
			it(
				"should call the callback when an entity with at least the required components is added",
				function(context)
					local registry = context.registry
					local called = false
					local testEntity = registry:createEntity()
					local reactor = createTestReactor(registry, {
						withAll = { "Test1", "Test2", "Test3" },
					})

					reactor.added:connect(function(entity, test1, test2, test3)
						called = true
						expect(entity).to.equal(testEntity)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						expect(test3).to.equal(registry:getComponent(entity, "Test3"))
					end)

					registry:withComponents(testEntity, {
						Test1 = {},
						Test2 = {},
						Test3 = {},
					})

					expect(called).to.equal(true)
					expect(reactor._pool:getIndex(testEntity)).to.be.ok()
				end
			)
		end)

		describe("required + forbidden", function()
			it(
				"should call the callback when an entity with at least the required components and none of the forbidden components is added",
				function(context)
					local registry = context.registry
					local called = false
					local testEntity = registry:createEntity()
					local reactor = createTestReactor(registry, {
						withAll = { "Test1", "Test2" },
						without = { "Test3" },
					})

					reactor.added:connect(function(entity, test1, test2)
						called = true
						expect(entity).to.equal(testEntity)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
					end)

					registry:withComponents(testEntity, {
						Test1 = {},
						Test2 = {},
					})

					expect(called).to.equal(true)
					expect(reactor._pool:getIndex(testEntity)).to.be.ok()

					called = false
					registry:addComponent(testEntity, "Test3", {})
					expect(called).to.equal(false)
					expect(reactor._pool:getIndex(testEntity)).to.never.be.ok()
				end
			)
		end)

		describe("updated + required + forbidden", function()
			it(
				"should call the callback when an entity with at least the required components, none of the forbidden components, and all of the updated components is added",
				function(context)
					local registry = context.registry
					local testEntity = registry:createEntity()
					local called = false
					local reactor = createTestReactor(registry, {
						withAll = { "Test1" },
						withUpdated = { "Test2", "Test4" },
						without = { "Test3" },
					})

					reactor.added:connect(function(entity, test1, test2, test4)
						called = true
						expect(entity).to.equal(testEntity)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						expect(test4).to.equal(registry:getComponent(entity, "Test4"))
					end)

					registry:withComponents(testEntity, {
						Test1 = {},
						Test2 = {},
						Test4 = {},
					})

					expect(called).to.equal(false)

					registry:replaceComponent(testEntity, "Test4", {})
					registry:replaceComponent(testEntity, "Test2", {})
					expect(called).to.equal(true)
					expect(reactor._pool:getIndex(testEntity)).to.be.ok()

					called = false
					registry:addComponent(testEntity, "Test3", {})
					expect(reactor._pool:getIndex(testEntity)).to.never.be.ok()

					registry:replaceComponent(testEntity, "Test4", {})
					registry:replaceComponent(testEntity, "Test2", {})
					expect(called).to.equal(false)
					expect(reactor._pool:getIndex(testEntity)).to.never.be.ok()
				end
			)

			it("should not fire twice when a component is updated twice", function(context)
				local registry = context.registry
				local called = false
				local reactor = createTestReactor(registry, {
					withAll = { "Test1", "Test2" },
					withUpdated = { "Test4" },
				})

				reactor.added:connect(function()
					called = true
				end)

				local testEntity = registry:createEntity()

				registry:withComponents(testEntity, {
					Test1 = {},
					Test2 = {},
					Test4 = {},
				})

				registry:replaceComponent(testEntity, "Test4", {})
				registry:replaceComponent(testEntity, "Test4", {})
				expect(called).to.equal(true)
			end)
		end)

		describe("required + optional", function()
			it(
				"should call the callback when an entity with at least the required components and any of the optional components is added",
				function(context)
					local registry = context.registry
					local called = false
					local testEntity = registry:createEntity()
					local reactor = createTestReactor(registry, {
						withAll = { "Test1", "Test2" },
						withAny = { "Test3", "Test4" },
					})

					reactor.added:connect(function(entity, test1, test2, test3, test4)
						called = true
						expect(entity).to.equal(testEntity)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						expect(test3).to.equal(registry:getComponent(entity, "Test3"))
						expect(test4).to.equal(registry:getComponent(entity, "Test4"))
					end)

					registry:withComponents(testEntity, {
						Test1 = {},
						Test2 = {},
						Test3 = {},
						Test4 = {},
					})

					expect(called).to.equal(true)
					expect(reactor._pool:getIndex(testEntity)).to.be.ok()
				end
			)
		end)
	end)

	describe("removed", function()
		describe("required", function()
			it(
				"should call the callback when an entity with at least the required components is untracked",
				function(context)
					local registry = context.registry
					local called = false
					local testEntity = registry:createEntity()
					local reactor = createTestReactor(registry, {
						withAll = { "Test1", "Test2", "Test3" },
					})

					reactor.removed:connect(function(entity, test1, test2, test3)
						called = true
						expect(entity).to.equal(testEntity)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						expect(test3).to.equal(registry:getComponent(entity, "Test3"))
					end)

					registry:withComponents(testEntity, {
						Test1 = {},
						Test2 = {},
						Test3 = {},
					})

					registry:removeComponent(testEntity, "Test2")
					expect(called).to.equal(true)
					expect(reactor._pool:getIndex(testEntity)).to.never.be.ok()
				end
			)
		end)

		describe("required + forbidden", function()
			it(
				"should call the callback when an entity with at least the required components and none of the forbidden components is untracked",
				function(context)
					local registry = context.registry
					local called = false
					local testEntity = registry:createEntity()
					local reactor = createTestReactor(registry, {
						withAll = { "Test1", "Test2" },
						without = { "Test3" },
					})

					reactor.removed:connect(function(entity, test1, test2)
						called = true
						expect(entity).to.equal(testEntity)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
					end)

					registry:withComponents(testEntity, {
						Test1 = {},
						Test2 = {},
					})

					registry:addComponent(testEntity, "Test3", {})
					expect(called).to.equal(true)
					expect(reactor._pool:getIndex(testEntity)).to.never.be.ok()
				end
			)
		end)

		describe("updated + required + forbidden", function()
			it(
				"should call the callback when an entity with at least the required components, none of the forbidden components, and all of the updated components is untracked",
				function(context)
					local registry = context.registry
					local called = false
					local testEntity = registry:createEntity()
					local reactor = createTestReactor(registry, {
						withAll = { "Test1", "Test2" },
						withUpdated = { "Test4" },
						without = { "Test3" },
					})

					reactor.removed:connect(function(entity, test1, test2, test4)
						called = true
						expect(entity).to.equal(testEntity)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						expect(test4).to.equal(registry:getComponent(entity, "Test4"))
					end)

					registry:withComponents(testEntity, {
						Test1 = {},
						Test2 = {},
						Test4 = {},
					})

					registry:replaceComponent(testEntity, "Test4", {})
					registry:removeComponent(testEntity, "Test2", {})
					expect(reactor._pool:getIndex(testEntity)).to.never.be.ok()
					expect(called).to.equal(true)
				end
			)
		end)

		it(
			"should stop tracking updates on an entity after all updated components have been removed",
			function(context)
				local registry = context.registry
				local testEntity = registry:createEntity()
				local reactor = createTestReactor(registry, {
					withAll = { "Test1", "Test2" },
					withUpdated = { "Test4" },
					without = { "Test3" },
				})

				registry:withComponents(testEntity, {
					Test1 = {},
					Test2 = {},
					Test4 = {},
				})

				registry:replaceComponent(testEntity, "Test4", {})
				registry:removeComponent(testEntity, "Test4")
				expect(reactor._pool:getIndex(testEntity)).to.never.be.ok()
				expect(reactor._updates[testEntity]).to.equal(nil)
			end
		)
	end)

	describe("withAttachments", function()
		it("should attach attachments when an entity enters the reactor", function(context)
			local registry = context.registry
			local event = Instance.new("BindableEvent")
			local numCalled = 0
			local holes = {}
			local reactor, _, len = createTestReactor(registry, {
				withAll = { "Test1", "Test2" },
			}, function()
				local hole = Instance.new("Hole")

				hole.Parent = workspace
				table.insert(holes, hole)

				return {
					hole,
					event.Event:Connect(function()
						numCalled += 1
					end),
				}
			end)

			event:Fire()
			expect(numCalled).to.equal(len)
			numCalled = 0

			reactor:each(function(entity)
				registry:removeComponent(entity, "Test2")
			end)

			event:Fire()
			expect(numCalled).to.equal(0)

			for _, hole in ipairs(holes) do
				expect(function()
					hole.Parent = workspace
				end).to.throw()
			end
		end)
	end)

	describe("detach", function()
		it("should detach every item from every entity in the reactor", function(context)
			local registry = context.registry
			local event = Instance.new("BindableEvent")
			local numCalled = 0
			local reactor = createTestReactor(registry, {
				withAll = { "Test1", "Test2" },
			}, function()
				return {
					event.Event:Connect(function()
						numCalled += 1
					end),
				}
			end)

			reactor:detach()

			event:Fire()
			expect(numCalled).to.equal(0)
		end)
	end)

	describe("consumeEach", function()
		it(
			"should remove each entity from the pool and clear their update states",
			function(context)
				local reactor, toIterate = createTestReactor(context.registry, {
					withUpdated = { "Test1" },
				})

				reactor:consumeEach(function(entity)
					expect(toIterate[entity]).to.be.ok()
					toIterate[entity] = nil
				end)

				expect(next(toIterate)).to.equal(nil)
				expect(next(reactor._pool.dense)).to.equal(nil)
				expect(next(reactor._updates)).to.equal(nil)
			end
		)
	end)

	describe("consume", function()
		it("should remove the entity from the pool and clear its update state", function(context)
			local registry = context.registry
			local reactor = createTestReactor(registry, {
				withAll = { "Test1" },
				withUpdated = { "Test2" },
			})

			local entity = registry:withComponents(registry:createEntity(), {
				Test1 = {},
				Test2 = {},
			})

			registry:replaceComponent(entity, "Test2", {})
			reactor:consume(entity)

			expect(reactor._pool:get(entity)).to.equal(nil)
			expect(reactor._updates[entity]).to.equal(nil)
		end)
	end)

	describe("_pack", function()
		it(
			"should pack the required and updated components of the entity into _packed",
			function(context)
				local registry = context.registry
				local reactor = createTestReactor(registry, {
					withAll = { "Test2", "Test3" },
					withUpdated = { "Test3", "Test4" },
				})

				local entity = context.registry:withComponents(context.registry:createEntity(), {
					Test1 = {},
					Test2 = {},
					Test3 = {},
					Test4 = {},
				})

				reactor:_pack(entity)

				expect(reactor._packed[1]).to.equal(context.registry:getComponent(entity, "Test2"))
				expect(reactor._packed[2]).to.equal(context.registry:getComponent(entity, "Test3"))
				expect(reactor._packed[3]).to.equal(context.registry:getComponent(entity, "Test3"))
				expect(reactor._packed[4]).to.equal(context.registry:getComponent(entity, "Test4"))
			end
		)
	end)

	describe("_tryPack", function()
		it(
			"should pack required and optional components and return true if the entity has all of them",
			function(context)
				local registry = context.registry
				local reactor = createTestReactor(registry, {
					withAll = { "Test1", "Test2" },
					withAny = { "Test4" },
					without = { "Test3" },
				})

				local entity = registry:withComponents(registry:createEntity(), {
					Test1 = {},
					Test2 = {},
					Test4 = {},
				})

				expect(reactor:_tryPack(entity)).to.equal(true)

				expect(reactor._packed[1]).to.equal(registry:getComponent(entity, "Test1"))
				expect(reactor._packed[2]).to.equal(registry:getComponent(entity, "Test2"))
				expect(reactor._packed[3]).to.equal(registry:getComponent(entity, "Test4"))

				expect(reactor:_tryPack(registry:withComponents(registry:createEntity(), {
					Test1 = {},
					Test2 = {},
					Test3 = {},
					Test4 = {},
				}))).to.equal(false)
			end
		)
	end)
end

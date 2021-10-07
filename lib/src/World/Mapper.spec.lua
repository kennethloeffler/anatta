return function()
	local Mapper = require(script.Parent.Mapper)
	local SingleMapper = require(script.Parent.SingleMapper)
	local Registry = require(script.Parent.Registry)
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

	local function createTestMapper(registry, query)
		local toIterate = {}
		local mapper = Mapper.new(registry, query)

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
			then
				toIterate[entity] = true
			end
		end

		return mapper, toIterate
	end

	describe("new", function()
		it("should create a new Mapper when there are  multiple components", function(context)
			local mapper = Mapper.new(context.registry, {
				withAll = { "Test1" },
				without = { "Test2" },
			})

			expect(getmetatable(mapper)).to.equal(Mapper)
		end)

		it(
			"should create a new SingleMapper when there is only one required component ",
			function(context)
				local mapper = Mapper.new(context.registry, {
					withAll = { "Test1" },
				})

				expect(getmetatable(mapper)).to.equal(SingleMapper)
			end
		)
	end)

	describe("update", function()
		describe("all", function()
			it(
				"should iterate all and only the entities with at least the required components and pass them plus any optional ones",
				function(context)
					local registry = context.registry
					local mapper, toIterate = createTestMapper(registry, {
						withAll = { "Test1", "Test2" },
						withAny = { "Test3", "Test4" },
					})

					mapper:update(function(entity, test1, test2, test3, test4)
						expect(toIterate[entity]).to.equal(true)
						expect(test1).to.equal(registry:getComponent(entity, "Test1"))
						expect(test2).to.equal(registry:getComponent(entity, "Test2"))
						expect(test3).to.equal(registry:getComponent(entity, "Test3"))
						expect(test4).to.equal(registry:getComponent(entity, "Test4"))
						toIterate[entity] = nil

						return test1, test2, test3, test4
					end)

					expect(next(toIterate)).to.equal(nil)
				end
			)

			it(
				"should replace required components with ones returned by the callback",
				function(context)
					local registry = context.registry
					local mapper, toIterate = createTestMapper(registry, {
						withAll = { "Test1", "Test2" },
					})

					mapper:update(function(entity)
						local newTest1 = {}
						local newTest2 = {}

						toIterate[entity] = { newTest1, newTest2 }

						return newTest1, newTest2
					end)

					mapper:update(function(entity, test1, test2)
						expect(test1).to.equal(toIterate[entity][1])
						expect(test2).to.equal(toIterate[entity][2])

						return test1, test2
					end)
				end
			)
		end)
	end)
end

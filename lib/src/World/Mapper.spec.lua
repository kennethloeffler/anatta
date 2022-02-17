return function()
	local Mapper = require(script.Parent.Mapper)
	local SingleMapper = require(script.Parent.SingleMapper)
	local Registry = require(script.Parent.Registry)
	local T = require(script.Parent.Parent.Core.T)

	local Component = {
		Test1 = {
			name = "Test1",
			type = T.table,
		},
		Test2 = {
			name = "Test2",
			type = T.table,
		},
		Test3 = {
			name = "Test3",
			type = T.table,
		},
		Test4 = {
			name = "Test4",
			type = T.table,
		},
		TestTag = {
			name = "TestTag",
			type = T.none,
		},
	}

	beforeEach(function(context)
		local registry = Registry.new()

		for _, definition in pairs(Component) do
			registry:defineComponent(definition)
		end

		context.registry = registry
	end)

	local function createTestMapper(registry, query)
		local toIterate = {}
		local mapper = Mapper.new(registry, query)

		for i = 1, 100 do
			local entity = registry:createEntity()

			if i % 2 == 0 then
				registry:addComponent(entity, Component.Test1, {})
				registry:addComponent(entity, Component.TestTag)
			end

			if i % 3 == 0 then
				registry:addComponent(entity, Component.Test2, {})
			end

			if i % 4 == 0 then
				registry:addComponent(entity, Component.Test3, {})
			end

			if i % 5 == 0 then
				registry:addComponent(entity, Component.Test4, {})
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
				withAll = { Component.Test1 },
				without = { Component.Test2 },
			})

			expect(getmetatable(mapper)).to.equal(Mapper)
		end)

		it("should create a new SingleMapper when there is only one required component ", function(context)
			local mapper = Mapper.new(context.registry, {
				withAll = { Component.Test1 },
			})

			expect(getmetatable(mapper)).to.equal(SingleMapper)
		end)
	end)

	describe("find", function()
		it("should return whatever is returned from the callback", function(context)
			local registry = context.registry
			local mapper = createTestMapper(registry, {
				withAll = { Component.Test1 },
				without = { Component.Test2 },
			})

			local expected = registry:addComponent(registry:createEntity(), Component.Test1, {})

			local found = mapper:find(function(_, component)
				if expected == component then
					return component
				end
			end)

			expect(found).to.equal(expected)
		end)
	end)

	describe("filter", function()
		it("should fill and return a table with whatever is returned from the callback", function(context)
			local registry = context.registry
			local mapper = createTestMapper(registry, {
				withAll = { Component.Test1 },
				without = { Component.Test2 },
			})

			local expected = {}
			for _ = 1, 10 do
				table.insert(expected, registry:addComponent(registry:createEntity(), Component.Test1, {}))
			end

			local results = mapper:filter(function(_, component)
				if table.find(expected, component) ~= nil then
					return component
				end
			end)

			for i, v in ipairs(results) do
				expect(v).to.equal(expected[i])
			end
		end)
	end)

	describe("map", function()
		describe("all", function()
			it(
				"should iterate all and only the entities with at least the required components and pass them plus any optional ones",
				function(context)
					local registry = context.registry
					local mapper, toIterate = createTestMapper(registry, {
						withAll = { Component.Test1, Component.Test2 },
						withAny = { Component.Test3, Component.Test4 },
					})

					mapper:map(function(entity, test1, test2, test3, test4)
						expect(toIterate[entity]).to.equal(true)
						expect(test1).to.equal(registry:getComponent(entity, Component.Test1))
						expect(test2).to.equal(registry:getComponent(entity, Component.Test2))
						expect(test3).to.equal(registry:getComponent(entity, Component.Test3))
						expect(test4).to.equal(registry:getComponent(entity, Component.Test4))
						toIterate[entity] = nil

						return test1, test2, test3, test4
					end)

					expect(next(toIterate)).to.equal(nil)
				end
			)

			it("should replace required components with ones returned by the callback", function(context)
				local registry = context.registry
				local mapper, toIterate = createTestMapper(registry, {
					withAll = { Component.Test1, Component.Test2 },
				})

				mapper:map(function(entity)
					local newTest1 = {}
					local newTest2 = {}

					toIterate[entity] = { newTest1, newTest2 }

					return newTest1, newTest2
				end)

				mapper:map(function(entity, test1, test2)
					expect(test1).to.equal(toIterate[entity][1])
					expect(test2).to.equal(toIterate[entity][2])

					return test1, test2
				end)
			end)
		end)
	end)
end

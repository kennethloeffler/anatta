return function()
	local PureCollection = require(script.Parent.PureCollection)
	local SinglePureCollection = require(script.Parent.SinglePureCollection)
	local Registry = require(script.Parent.Registry)
	local t = require(script.Parent.Parent.Core.Type)

	local function getCollection(registry, system)
		system.registry = registry

		local toIterate = {}
		local collection = PureCollection.new(system)

		for i = 1, 100 do
			local entity = registry:createEntity()

			if i % 2 == 0 then
				registry:addComponent(entity, "Test1", {})
				registry:addComponent(entity, "Test5")
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
				registry:hasAllComponents(entity, unpack(system.required))
				and not registry:hasAnyComponents(entity, unpack(system.forbidden))
			then
				toIterate[entity] = true
			end
		end

		return collection, toIterate
	end

	beforeEach(function(context)
		context.registry = Registry.new({
			Test1 = t.table,
			Test2 = t.table,
			Test3 = t.table,
			Test4 = t.table,
			Test5 = t.none,
		})
	end)

	describe("new", function()
		it(
			"should create a new PureCollection when there are  multiple components",
			function(context)
				local collection = PureCollection.new({
					required = { "Test1" },
					forbidden = { "Test2" },
					optional = {},
					registry = context.registry,
				})

				expect(getmetatable(collection)).to.equal(PureCollection)
			end
		)

		it(
			"should create a new SinglePureCollection when there is only one required component ",
			function(context)
				local collection = PureCollection.new({
					required = { "Test1" },
					forbidden = {},
					optional = {},
					registry = context.registry,
				})

				expect(getmetatable(collection)).to.equal(SinglePureCollection)
			end
		)
	end)

	describe("update", function()
		describe("all", function()
			it(
				"should iterate all and only the entities with at least the required components and pass them plus any optional ones",
				function(context)
					local registry = context.registry
					local collection, toIterate = getCollection(registry, {
						required = { "Test1", "Test2" },
						optional = { "Test3", "Test4" },
						forbidden = {},
					})

					collection:update(function(entity, test1, test2, test3, test4)
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
					local collection, toIterate = getCollection(registry, {
						required = { "Test1", "Test2" },
						forbidden = {},
						optional = {},
					})

					collection:update(function(entity)
						local newTest1 = {}
						local newTest2 = {}

						toIterate[entity] = { newTest1, newTest2 }

						return newTest1, newTest2
					end)

					collection:update(function(entity, test1, test2)
						expect(test1).to.equal(toIterate[entity][1])
						expect(test2).to.equal(toIterate[entity][2])

						return test1, test2
					end)
				end
			)
		end)
	end)
end

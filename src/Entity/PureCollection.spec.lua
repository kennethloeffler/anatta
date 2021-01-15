return function()
	local PureCollection = require(script.Parent.PureCollection)
	local SinglePureCollection = require(script.Parent.SinglePureCollection)
	local Registry = require(script.Parent.Registry)
	local t = require(script.Parent.Parent.t)

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
		it("should create a new PureCollection when there are  multiple components", function(context)
			local collection = PureCollection.new(context.registry, {
				required = { "Test1" },
				forbidden = { "Test2" },
			})

			expect(getmetatable(collection)).to.equal(PureCollection)
		end)

		it("should create a new SinglePureCollection when there is only one required component ", function(context)
			local collection = PureCollection.new(context.registry, {
				required = { "Test1" },
			})

			expect(getmetatable(collection)).to.equal(SinglePureCollection)
		end)
	end)

	describe("each", function()
		describe("required", function()
			it("should iterate all and only the entities with at least the required components and pass their data", function(context)
				local registry = context.registry
				local collection = PureCollection.new(registry, {
					required = { "Test1", "Test2", "Test3" }
				})
				local toIterate = {}

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

					return test1, test2, test3
				end)

				expect(next(toIterate)).to.equal(nil)
			end)

			it("should replace required components with ones returned by the callback", function(context)
				local registry = context.registry
				local collection = PureCollection.new(registry, {
					required = { "Test1", "Test2" }
				})
				local toIterate = {}

				makeEntities(registry)

				collection:each(function(entity)
					local newTest1 = {}
					local newTest2 = {}

					toIterate[entity] = { newTest1, newTest2 }

					return newTest1, newTest2
				end)

				collection:each(function(entity, test1, test2)
					expect(test1).to.equal(toIterate[entity][1])
					expect(test2).to.equal(toIterate[entity][2])
				end)
			end)
		end)
	end)
end

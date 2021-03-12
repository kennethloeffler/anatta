return function()
	local PureCollection = require(script.Parent.PureCollection)
	local SinglePureCollection = require(script.Parent.SinglePureCollection)
	local Registry = require(script.Parent.Registry)
	local Matcher = require(script.Parent.Matcher)
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
		context.registry = Registry.new({
			Test1 = t.table,
			Test2 = t.table,
			Test3 = t.table,
			Test4 = t.table,
		})
	end)

	describe("new", function()
		it("should create a new PureCollection when there are  multiple components", function(context)
			local collection = PureCollection.new(
				Matcher.new(context.registry):all("Test1"):except("Test2")
			)

			expect(getmetatable(collection)).to.equal(PureCollection)
		end)

		it("should create a new SinglePureCollection when there is only one required component ", function(context)
			local collection = PureCollection.new(
				Matcher.new(context.registry):all("Test1")
			)

			expect(getmetatable(collection)).to.equal(SinglePureCollection)
		end)
	end)

	describe("update", function()
		describe("all", function()
			it("should iterate all and only the entities with at least the required components and pass them plus any optional ones", function(context)
				local registry = context.registry
				local toIterate = {}
				local collection = PureCollection.new(
					Matcher.new(registry)
					:all("Test1", "Test2"):any("Test3", "Test4")
				)

				makeEntities(registry)

				for _, entity in ipairs(registry._pools.Test1.dense) do
					if registry:has(entity, "Test2") then
						toIterate[entity] = true
					end
				end

				collection:update(function(entity, test1, test2, test3, test4)
					expect(toIterate[entity]).to.equal(true)
					expect(test1).to.equal(registry:get(entity, "Test1"))
					expect(test2).to.equal(registry:get(entity, "Test2"))
					expect(test3).to.equal(registry:get(entity, "Test3"))
					expect(test4).to.equal(registry:get(entity, "Test4"))
					toIterate[entity] = nil

					return test1, test2, test3, test4
				end)

				expect(next(toIterate)).to.equal(nil)
			end)

			it("should replace required components with ones returned by the callback", function(context)
				local registry = context.registry
				local collection = PureCollection.new(
					Matcher.new(registry):all("Test1", "Test2")
				)
				local toIterate = {}

				makeEntities(registry)

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
			end)
		end)
	end)
end

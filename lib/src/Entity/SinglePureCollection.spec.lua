return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local SinglePureCollection = require(script.Parent.SinglePureCollection)

	describe("new", function()
		it("should create a new SinglePureCollection from a pool", function()
			local pool = Pool.new("test", {})
			local collection = SinglePureCollection.new(pool)

			expect(getmetatable(collection)).to.equal(SinglePureCollection)
			expect(collection._pool).to.equal(pool)
		end)
	end)

	describe("each", function()
		it("should iterate all and only the elements in the pool and pass their data", function()
			local pool = Pool.new("test", {})
			local collection = SinglePureCollection.new(pool)
			local toIterate = {}

			for i = 1, 100 do
				local obj = {}
				pool:insert(i, obj)
				toIterate[i] = obj
			end

			collection:each(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])
				toIterate[entity] = nil

				return obj
			end)

			expect(next(toIterate)).to.never.be.ok()
		end)
	end)

	describe("update", function()
		it("should iterate all and only the elements in the pool and pass their data", function()
			local pool = Pool.new("test", {})
			local collection = SinglePureCollection.new(pool)
			local toIterate = {}

			for i = 1, 100 do
				local obj = {}
				pool:insert(i, obj)
				toIterate[i] = obj
			end

			collection:update(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])
				toIterate[entity] = nil

				return obj
			end)

			expect(next(toIterate)).to.never.be.ok()
		end)

		it("should replace the passed data with the returned data", function()
			local pool = Pool.new("test", {})
			local collection = SinglePureCollection.new(pool)
			local toIterate = {}

			for i = 1, 100 do
				local obj = {}
				pool:insert(i, obj)
				toIterate[i] = obj
			end

			collection:update(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])

				toIterate[entity] = {}

				return toIterate[entity]
			end)

			collection:each(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])
			end)
		end)
	end)
end

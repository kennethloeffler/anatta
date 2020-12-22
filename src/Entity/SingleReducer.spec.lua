return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local SingleReducer = require(script.Parent.SingleReducer)

	describe("new", function()
		it("should create a new SingleReducer from a pool", function()
			local pool = Pool.new()
			local reducer = SingleReducer.new(pool)

			expect(getmetatable(reducer)).to.equal(SingleReducer)
			expect(reducer._pool).to.equal(pool)
		end)
	end)

	describe("entities", function()
		it("should iterate all and only the elements in the pool", function()
			local pool = Pool.new()
			local reducer = SingleReducer.new(pool)
			local toIterate = {}

			for i = 1, 100 do
				pool:insert(i, i)
				toIterate[i] = true
			end

			reducer:entities(function(entity)
				toIterate[entity] = nil
			end)

			expect(next(toIterate)).to.never.be.ok()
		end)
	end)

	describe("each", function()
		it("should iterate all and only the elements in the pool and pass their data", function()
			local pool = Pool.new()
			local reducer = SingleReducer.new(pool)
			local toIterate = {}

			for i = 1, 100 do
				local obj = {}
				pool:insert(i, obj)
				toIterate[i] = obj
			end

			reducer:each(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])
				toIterate[entity] = nil

				return obj
			end)

			expect(next(toIterate)).to.never.be.ok()
		end)

		it("should replace the passed data with the returned data", function()
			local pool = Pool.new()
			local reducer = SingleReducer.new(pool)
			local toIterate = {}

			for i = 1, 100 do
				local obj = {}
				pool:insert(i, obj)
				toIterate[i] = obj
			end

			reducer:each(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])

				toIterate[entity] = {}

				return toIterate[entity]
			end)

			reducer:each(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])
			end)
		end)
	end)
end

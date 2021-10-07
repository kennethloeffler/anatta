return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local SingleMapper = require(script.Parent.SingleMapper)

	describe("new", function()
		it("should create a new SingleMapper from a pool", function()
			local pool = Pool.new({ name = "test", type = {} })
			local mapper = SingleMapper.new(pool)

			expect(getmetatable(mapper)).to.equal(SingleMapper)
			expect(mapper._pool).to.equal(pool)
		end)
	end)

	describe("each", function()
		it("should iterate all and only the elements in the pool and pass their data", function()
			local pool = Pool.new({ name = "test", type = {} })
			local mapper = SingleMapper.new(pool)
			local toIterate = {}

			for i = 1, 100 do
				local obj = {}
				pool:insert(i, obj)
				toIterate[i] = obj
			end

			mapper:each(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])
				toIterate[entity] = nil

				return obj
			end)

			expect(next(toIterate)).to.never.be.ok()
		end)
	end)

	describe("map", function()
		it("should iterate all and only the elements in the pool and pass their data", function()
			local pool = Pool.new({ name = "test", type = {} })
			local mapper = SingleMapper.new(pool)
			local toIterate = {}

			for i = 1, 100 do
				local obj = {}
				pool:insert(i, obj)
				toIterate[i] = obj
			end

			mapper:map(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])
				toIterate[entity] = nil

				return obj
			end)

			expect(next(toIterate)).to.never.be.ok()
		end)

		it("should replace the passed data with the returned data", function()
			local pool = Pool.new({ name = "test", type = {} })
			local mapper = SingleMapper.new(pool)
			local toIterate = {}

			for i = 1, 100 do
				local obj = {}
				pool:insert(i, obj)
				toIterate[i] = obj
			end

			mapper:map(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])

				toIterate[entity] = {}

				return toIterate[entity]
			end)

			mapper:each(function(entity, obj)
				expect(obj).to.equal(toIterate[entity])
			end)
		end)
	end)
end

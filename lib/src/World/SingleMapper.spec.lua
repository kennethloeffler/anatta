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

	describe("find", function()
		it("should return whatever is returned from the callback", function()
			local pool = Pool.new({ name = "test", type = {} })
			local mapper = SingleMapper.new(pool)

			local expected = {}

			for i = 1, 10 do
				if i == 8 then
					pool:insert(i, expected)
				else
					pool:insert(i, {})
				end
			end

			local found = mapper:find(function(_, component)
				if expected == component then
					return component
				end
			end)

			expect(found).to.equal(expected)
		end)
	end)

	describe("filter", function()
		it("should fill and return a table with whatever is returned from the callback", function()
			local pool = Pool.new({ name = "test", type = {} })
			local mapper = SingleMapper.new(pool)

			local expected = {}
			for i = 1, 10 do
				pool:insert(i, i)
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

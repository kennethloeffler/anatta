return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local SingleSelector = require(script.Parent.SingleSelector)

	describe("new", function()
		it("should create a new SingleSelector from a pool", function()
			local pool = Pool.new()
			local selector = SingleSelector.new(pool)

			expect(selector._pool).to.equal(pool)
			expect(getmetatable(selector)).to.equal(SingleSelector)
		end)
	end)

	describe("entities", function()
		it("should iterate the entire pool", function()
			local pool = Pool.new()
			local toIterate = {}
			local selector = SingleSelector.new(pool)

			for i = 1, 100 do
				toIterate[i] = true
				pool:insert(i)
			end

			selector:entities(function(entity)
				toIterate[entity] = nil
			end)

			expect(next(toIterate)).to.equal(nil)
		end)
	end)

	describe("each", function()
		it("should iterate the entire pool and pass each element's data", function()
			local pool = Pool.new()
			local toIterate = {}
			local selector = SingleSelector.new(pool)

			for i = 1, 100 do
				toIterate[i] = true
				pool:insert(i, i)
			end

			selector:each(function(entity, val)
				toIterate[entity] = nil
				expect(entity).to.equal(val)
			end)

			expect(next(toIterate)).to.equal(nil)
		end)
	end)

	describe("onAdded", function()
		it("should connect the callback to the pool's added signal", function()
			local pool = Pool.new()
			local selector = SingleSelector.new(pool)
			local called = false

			selector:onAdded(function()
				called = true
			end)

			selector._pool.onAdd:dispatch()
			expect(called).to.equal(true)
		end)
	end)

	describe("onRemoved", function()
		it("should connect the callback to the pool's removed signal", function()
			local pool = Pool.new()
			local selector = SingleSelector.new(pool)
			local called = false

			selector:onRemoved(function()
				called = true
			end)

			selector._pool.onRemove:dispatch()
			expect(called).to.equal(true)
		end)		
	end)
end

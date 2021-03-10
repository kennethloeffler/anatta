return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local SingleCollection = require(script.Parent.SingleCollection)

	describe("new", function()
		it("should create a new SingleCollection from a pool", function()
			local pool = Pool.new()
			local collection = SingleCollection.new(pool)

			expect(getmetatable(collection)).to.equal(SingleCollection)
			expect(collection.added).to.equal(pool.added)
			expect(collection.removed).to.equal(pool.removed)
			expect(collection._componentPool).to.equal(pool)
		end)
	end)

	describe("each", function()
		it("should iterate the entire pool and pass each element's data", function()
			local pool = Pool.new()
			local toIterate = {}
			local collection = SingleCollection.new(pool)

			for i = 1, 100 do
				toIterate[i] = true
				pool:insert(i, i)
			end

			collection:each(function(entity, val)
				toIterate[entity] = nil
				expect(entity).to.equal(val)
			end)

			expect(next(toIterate)).to.equal(nil)
		end)
	end)
end

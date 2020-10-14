return function()
	local Constants = require(script.Parent.Constants)
	local Pool = require(script.Parent.Pool)

	local ENTITYID_MASK = Constants.ENTITYID_MASK
	local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH

	local function generate(pool)
		local rand = Random.new()
		local size = 0

		for _ = 1, 200 do
			local id = rand:NextInteger(1, 2^16 - 1)
			local version = bit32.lshift(rand:NextInteger(1, 2^16 - 1), ENTITYID_WIDTH)

			if not pool.sparse[id] then
				size += 1
				pool:assign(bit32.bor(id, version))
			end
		end

		return pool, size
	end

	describe("new", function()
		local pool = Pool.new()

		it("should return a new empty pool", function()
			expect(pool).to.be.a("table")
			expect(next(pool.objects)).to.never.be.ok()
			expect(next(pool.sparse)).to.never.be.ok()
			expect(next(pool.dense)).to.never.be.ok()
			expect(pool.size).to.equal(0)
		end)

		it("should have lifecycle events", function()
			expect(pool.onAdd).to.be.ok()
			expect(pool.onRemove).to.be.ok()
			expect(pool.onUpdate).to.be.ok()
		end)
	end)

	describe("assign", function()
		it("should add an element and return the passed component object", function()
			local pool = Pool.new()
			local obj = {}
			local val = 0xBADF00D
			local component = pool:assign(val, obj)
			local _, objInPool = next(pool.objects)

			expect(component).to.equal(obj)
			expect(objInPool).to.equal(component)
		end)

		it("should construct the sparse array correctly", function()
			local pool, size = generate(Pool.new())

			expect(pool.size).to.equal(size)

			for i, v in ipairs(pool.dense) do
				expect(pool.sparse[bit32.band(v, ENTITYID_MASK)]).to.equal(i)
			end
		end)
	end)

	describe("get", function()
	end)

	describe("destroy", function()
		it("should empty the pool when all elements are removed", function()
			local pool, size = generate(Pool.new())

			for i = size, 1, -1 do
				pool:destroy(pool.dense[i])
			end

			expect(next(pool.objects)).to.never.be.ok()
			expect(next(pool.sparse)).to.never.be.ok()
			expect(next(pool.dense)).to.never.be.ok()
			expect(pool.size).to.equal(0)
		end)

		it("should swap the last element into the removed element's place when there is more than one element in the pool", function()
			local pool, size = generate(Pool.new())
			local last = pool.dense[size]
			local toRemove = pool.dense[size - 50]

			pool:destroy(toRemove)

			expect(pool.dense[size - 50]).to.equal(last)
		end)
	end)
end

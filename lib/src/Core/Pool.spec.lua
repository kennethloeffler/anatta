return function()
	local Constants = require(script.Parent.Constants)
	local Pool = require(script.Parent.Pool)

	local ENTITYID_OFFSET = Constants.EntityIdOffset
	local ENTITYID_WIDTH = Constants.EntityIdWidth
	local VERSION_WIDTH = Constants.VersionWidth

	local function generate(pool)
		local rand = Random.new()
		local size = 0

		for _ = 1, 200 do
			local id = rand:NextInteger(1, 2 ^ ENTITYID_WIDTH - 1)
			local version = bit32.lshift(rand:NextInteger(1, 2 ^ VERSION_WIDTH - 1), ENTITYID_WIDTH)

			if not pool.sparse[id] then
				size += 1
				pool:insert(bit32.bor(id, version))
			end
		end

		return pool, size
	end

	describe("new", function()
		local pool = Pool.new({ type = {} })

		it("should return a new empty pool", function()
			expect(pool).to.be.a("table")
			expect(next(pool.components)).to.never.be.ok()
			expect(next(pool.sparse)).to.never.be.ok()
			expect(next(pool.dense)).to.never.be.ok()
			expect(pool.size).to.equal(0)
		end)

		it("should have lifecycle events", function()
			expect(pool.added).to.be.ok()
			expect(pool.removed).to.be.ok()
			expect(pool.updated).to.be.ok()
		end)
	end)

	describe("getIndex", function() end)

	describe("get", function() end)

	describe("replace", function() end)

	describe("insert", function()
		it("should add an element and return the passed component object", function()
			local pool = Pool.new({ type = {} })
			local obj = {}
			local val = 0xBADF00D
			local component = pool:insert(val, obj)
			local _, objInPool = next(pool.components)

			expect(component).to.equal(obj)
			expect(objInPool).to.equal(component)
		end)

		it("should construct the sparse array correctly", function()
			local pool, size = generate(Pool.new({ type = {} }))

			expect(pool.size).to.equal(size)

			for i, v in ipairs(pool.dense) do
				expect(pool.sparse[bit32.extract(v, ENTITYID_OFFSET, ENTITYID_WIDTH)]).to.equal(i)
			end
		end)
	end)

	describe("delete", function()
		it("should empty the pool when all elements are removed", function()
			local pool, size = generate(Pool.new({ type = {} }))

			for i = size, 1, -1 do
				pool:delete(pool.dense[i])
			end

			expect(next(pool.components)).to.never.be.ok()
			expect(next(pool.sparse)).to.never.be.ok()
			expect(next(pool.dense)).to.never.be.ok()
			expect(pool.size).to.equal(0)
		end)

		it(
			"should swap the last element into the removed element's place when there is more than one element in the pool",
			function()
				local pool, size = generate(Pool.new({ type = {} }))
				local last = pool.dense[size]
				local toRemove = pool.dense[size - 50]

				pool:delete(toRemove)

				expect(pool.dense[size - 50]).to.equal(last)
			end
		)
	end)
end

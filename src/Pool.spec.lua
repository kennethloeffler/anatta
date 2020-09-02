local Pool = require(script.Parent.Pool)
local obj = Vector3.new()
local Manifest = require(script.Parent.Manifest)
local t = require(script.Parent.core.t)

return function()
	describe("new", function()
		local tFunction = t.Vector3
		local pool = Pool.new("testPool", tFunction)

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

		it("should be of the correct type", function()
			expect(pool.tFunction).to.equal(tFunction)
		end)
	end)

	describe("assign", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local pool = Pool.new("testPool", typeof(obj))

		it("should correctly assign a component to an entity", function()
			local component = pool:assign(entity, obj)
			local _, objInPool = next(pool.objects)

			expect(component).to.equal(obj)
			expect(objInPool).to.equal(component)
		end)

		it("should return nil when the associated component is empty", function()
			pool = Pool.new()
			expect(pool:assign(entity)).to.never.be.ok()
		end)
	end)

	describe("get", function()
		local pool = Pool.new("testPool", typeof(obj))
		local manifest = Manifest.new()
		local entity = manifest:create()

		pool:assign(entity, obj)

		it("should correctly determine if an entity has a component", function()
			expect(pool:get(entity)).to.be.ok()
			expect(pool:get(manifest:create())).to.never.be.ok()
		end)

		it("should return the correct object", function()
			expect(pool:get(entity)).to.equal(obj)
		end)
	end)

	describe("destroy", function()
		local pool = Pool.new("testPool", typeof(obj))
		local manifest = Manifest.new()
		local entity = manifest:create()

		it("should correctly remove the component from the pool", function()
			pool:assign(entity, obj)
			pool:destroy(entity)

			expect(pool.objects[pool.sparse[entity]]).to.never.be.ok()
		end)

		it("should throw when the pool does not contain the component", function()
			expect(pcall(Pool.destroy, pool, 0)).to.equal(false)
		end)
	end)
end

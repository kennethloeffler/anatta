local Pool = require(script.Parent.Pool)
local obj = Vector3.new()
local Manifest = require(script.Parent.Manifest)

return function()
	describe("new", function()
		local ty = typeof(obj)
		local pool = Pool.new(ty)

		it("should return a new empty pool", function()
			expect(pool).to.be.a("table")
			expect(next(pool.objects)).to.never.be.ok()
		end)

		it("should have lifecycle events", function()
			expect(pool.onAssign).to.be.ok()
			expect(pool.onRemove).to.be.ok()
			expect(pool.onReplace).to.be.ok()
		end)

		it("should be of the correct type", function()
			expect(pool.type).to.equal(ty)
		end)

		it("should not have .objects when the associated component is empty", function()
			pool = Pool.new()
			expect(pool.objects).to.never.be.ok()
		end)

		it("should not have a type when the associated component is empty", function()
			pool = Pool.new()
			expect(pool.type).to.never.be.ok()
		end)
	end)

	describe("assign", function()
		local manifest = Manifest.new()
		local entity = manifest:create()
		local pool = Pool.new(typeof(obj))

		it("should correctly assign a component to an entity", function()
			local component = Pool.assign(pool, entity, obj)
			local _, objInPool = next(pool.objects)

			expect(component).to.equal(obj)
			expect(objInPool).to.equal(component)
		end)

		it("should return nil when the associated component is empty", function()
			pool = Pool.new()
			expect(Pool.assign(pool, entity)).to.never.be.ok()
		end)
	end)

	describe("get", function()
		local pool = Pool.new(typeof(obj))
		local manifest = Manifest.new()
		local entity = manifest:create()

		Pool.assign(pool, entity, obj)

		it("should correctly determine if an entity has a component", function()
			expect(Pool.get(pool, entity)).to.be.ok()
			expect(Pool.get(pool, manifest:create())).to.never.be.ok()
		end)

		it("should return the correct object", function()
			expect(Pool.get(pool, entity)).to.equal(obj)
		end)
	end)

	describe("destroy", function()
		local pool = Pool.new(typeof(obj))
		local manifest = Manifest.new()
		local entity = manifest:create()

		it("should correctly remove the component from the pool", function()
			Pool.assign(pool, entity, obj)
			Pool.destroy(pool, entity)

			expect(pool.objects[pool.external[entity]]).to.never.be.ok()
		end)

		it("should throw when the pool does not contain the component", function()
			expect(pcall(Pool.destroy, pool, 0)).to.equal(false)
		end)
	end)
end

return function()
	local Pool = require(script.Parent.Pool)
	local obj = Vector3.new()

	describe("new", function()
		local ty = typeof(obj)
		local pool = Pool.new(ty)

		it("should return a new empty pool", function()
			expect(pool).to.be.a("table")
			expect(next(pool.Objects)).to.never.be.ok()
		end)

		it("should have lifecycle events", function()
			expect(pool.OnAssign).to.be.ok()
			expect(pool.OnRemove).to.be.ok()
			expect(pool.OnUpdate).to.be.ok()
		end)

		it("should be of the correct type", function()
			expect(pool.Type).to.equal(ty)
		end)

		it("should not have .Objects when the associated component is empty", function()
			pool = Pool.new()
			expect(pool.Objects).to.never.be.ok()
		end)

		it("should not have a type when the associated component is empty", function()
			pool = Pool.new()
			expect(pool.Type).to.never.be.ok()
		end)
	end)

	describe("Assign", function()
		local Ecs = require(script.Parent).new()
		local entity = Ecs:Create()
		local pool = Pool.new(typeof(obj))

		it("should correctly assign a component to an entity", function()
			local component = Pool.Assign(pool, entity, obj)
			local _, objInPool = next(pool.Objects)

			expect(component).to.equal(obj)
			expect(objInPool).to.equal(component)
		end)

		it("should return nil when the associated component is empty", function()
			pool = Pool.new()
			expect(Pool.Assign(pool, entity)).to.never.be.ok()
		end)
	end)

	describe("Get", function()
		local pool = Pool.new(typeof(obj))
		local Ecs = require(script.Parent).new()
		local entity = Ecs:Create()

		Pool.Assign(pool, entity, obj)

		it("should correctly determine if an entity has a component", function()
			expect(Pool.Get(pool, entity)).to.be.ok()
			expect(Pool.Get(pool, Ecs:Create())).to.never.be.ok()
		end)

		it("should return the correct object", function()
			expect(Pool.Get(pool, entity)).to.equal(obj)
		end)
	end)

	describe("Destroy", function()
		local pool = Pool.new(typeof(obj))
		local Ecs = require(script.Parent).new()
		local entity = Ecs:Create()

		it("should correctly remove the component from the pool", function()
			Pool.Assign(pool, entity, obj)
			Pool.Destroy(pool, entity)

			expect(Pool.Get(pool, entity)).to.never.be.ok()
		end)

		it("should throw when the pool does not contain the component", function()
			expect(pcall(Pool.Destroy, pool, 0)).to.equal(false)
		end)
	end)
end

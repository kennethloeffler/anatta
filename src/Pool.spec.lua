return function()
	local Pool = require(script.Parent.Pool)
	local Manifest = require(script.Parent.Manifest)
	local obj = Vector3.new()
	local t = require(script.Parent.core.TypeDef)

	local ENTITYID_MASK = require(script.Parent.Constants).ENTITYID_MASK

	describe("new", function()
		local typeDef = t.Vector3
		local pool = Pool.new("testPool", typeDef)

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
			expect(pool.typeDef).to.be.a("table")
			expect(pool.typeDef.type).to.equal("Vector3")
		end)
	end)

	describe("assign", function()
		it("should add an element pool and return the passed component object", function()
			local manifest = Manifest.new()
			local entity = manifest:create()
			local pool = Pool.new("testPool", typeof(obj))
			local component = pool:assign(entity, obj)
			local _, objInPool = next(pool.objects)

			expect(component).to.equal(obj)
			expect(objInPool).to.equal(component)
		end)

		it("should return nil when the associated component is empty", function()
			local manifest = Manifest.new()
			local emptyTypedPool = Pool.new("i am of an empty type", t.none)

			expect(emptyTypedPool:assign(manifest:create())).to.equal(nil)
		end)

		it("should construct the sparse array correctly", function()
			local manifest = Manifest.new()
			local pool = Pool.new("testPool", t.none)

			for i = 1, 100 do
				local entity = manifest:create()
				-- destroy and recycle some so the test includes entities with
				-- non-zero versions
				if i % 2 == 0 then
					for _ = 1, math.random(1, 20) do
						manifest:destroy(entity)
						entity = manifest:create()
					end
				end
				pool:assign(entity)
				expect(pool.dense[pool.sparse[bit32.band(entity, ENTITYID_MASK)]])
					.to.equal(entity)
			end
		end)
	end)

	describe("get", function()
		local pool = Pool.new("testPool", t.number)
		local manifest = Manifest.new()

		it("should return the component object if the entity has the component, nil otherwise", function()
			local entity = manifest:create()

			pool:assign(entity, 0xF00F)
			expect(pool:get(entity)).to.equal(0xF00F)

			-- and one with an incremented version
			manifest:destroy(manifest:create())
			entity = manifest:create()
			pool:assign(entity, 0xDEAD)
			expect(pool:get(entity)).to.equal(0xDEAD)

			expect(pool:get(manifest:create())).to.equal(nil)
		end)
	end)

	describe("destroy", function()
		local pool = Pool.new("testPool", t.Vector3)
		local manifest = Manifest.new()
		local entity = manifest:create()

		it("it should remove an entity from the pool when there is only one element", function()
			pool:assign(entity, Vector3.new())
			pool:destroy(entity)
			expect(pool.objects[pool.sparse[bit32.band(entity, ENTITYID_MASK)]]).to.never.be.ok()
		end)


		it("should remove an entity from the pool and swap it for the ", function()
		end)

		it("should throw when the pool does not contain the component", function()
			expect(function()
				pool:destroy(manifest:create())
			end).to.throw(false)
		end)
	end)
end

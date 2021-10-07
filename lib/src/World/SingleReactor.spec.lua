return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local SingleReactor = require(script.Parent.SingleReactor)

	describe("new", function()
		it("should create a new SingleCollection from a pool", function()
			local pool = Pool.new("test", {})
			local collection = SingleReactor.new(pool)

			expect(getmetatable(collection)).to.equal(SingleReactor)
			expect(collection.added).to.equal(pool.added)
			expect(collection.removed).to.equal(pool.removed)
			expect(collection._componentPool).to.equal(pool)
		end)
	end)

	describe("each", function()
		it("should iterate the entire pool and pass each element's data", function()
			local pool = Pool.new("test", {})
			local toIterate = {}
			local collection = SingleReactor.new(pool)

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

	describe("withAttachments", function()
		it("should attach attachments when an entity enters the collection", function()
			local pool = Pool.new("test", {})
			local collection = SingleReactor.new(pool)
			local event = Instance.new("BindableEvent")
			local numCalled = 0
			local holes = {}

			collection:withAttachments(function()
				local hole = Instance.new("Hole")

				hole.Parent = workspace
				table.insert(holes, hole)

				return {
					hole,
					event.Event:Connect(function()
						numCalled += 1
					end),
				}
			end)

			for i = 1, 50 do
				pool:insert(i)
				pool.added:dispatch(i)
			end

			event:Fire()
			expect(numCalled).to.equal(50)
			numCalled = 0

			collection:each(function(entity)
				pool:delete(entity)
				pool.removed:dispatch(entity)
			end)

			event:Fire()
			expect(numCalled).to.equal(0)

			for _, hole in ipairs(holes) do
				expect(function()
					hole.Parent = workspace
				end).to.throw()
			end
		end)
	end)

	describe("detach", function()
		it("should detach every item from every entity in the collection", function()
			local pool = Pool.new("test", {})
			local collection = SingleReactor.new(pool)
			local event = Instance.new("BindableEvent")
			local numCalled = 0

			collection:withAttachments(function()
				return {
					event.Event:Connect(function()
						numCalled += 1
					end),
				}
			end)

			for i = 1, 50 do
				pool:insert(i)
				pool.added:dispatch(i)
			end

			collection:detach(collection)

			event:Fire()
			expect(numCalled).to.equal(0)
		end)
	end)
end
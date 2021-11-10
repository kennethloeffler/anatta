return function()
	local Pool = require(script.Parent.Parent.Core.Pool)
	local SingleReactor = require(script.Parent.SingleReactor)

	describe("new", function()
		it("should create a new SingleReactor from a pool", function()
			local pool = Pool.new({ name = "test", type = {} })
			local reactor = SingleReactor.new(pool)

			expect(getmetatable(reactor)).to.equal(SingleReactor)
			expect(reactor.added).to.equal(pool.added)
			expect(reactor.removed).to.equal(pool.removed)
			expect(reactor._componentPool).to.equal(pool)
		end)
	end)

	describe("find", function()
		it("should return whatever is returned from the callback", function()
			local pool = Pool.new({ name = "test", type = {} })
			local reactor = SingleReactor.new(pool)

			local expected = {}

			pool:insert(1, expected)

			local found = reactor:find(function(_, component)
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
			local reactor = SingleReactor.new(pool)

			local expected = {}

			for i = 1, 10 do
				local value = {}

				pool:insert(i, value)
				table.insert(expected, value)
			end

			local results = reactor:filter(function(_, component)
				if table.find(expected, component) ~= nil then
					return component
				end
			end)

			expect(#results).to.equal(#expected)

			for _, v in ipairs(results) do
				expect(table.find(expected, v)).to.be.ok()
			end
		end)
	end)

	describe("each", function()
		it("should iterate the entire pool and pass each element's data", function()
			local pool = Pool.new({ name = "test", type = {} })
			local toIterate = {}
			local reactor = SingleReactor.new(pool)

			for i = 1, 100 do
				toIterate[i] = true
				pool:insert(i, i)
			end

			reactor:each(function(entity, val)
				toIterate[entity] = nil
				expect(entity).to.equal(val)
			end)

			expect(next(toIterate)).to.equal(nil)
		end)
	end)

	describe("withAttachments", function()
		it("should attach attachments when an entity enters the reactor", function()
			local pool = Pool.new({ name = "test", type = {} })
			local reactor = SingleReactor.new(pool)
			local event = Instance.new("BindableEvent")
			local numCalled = 0
			local holes = {}

			reactor:withAttachments(function()
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

			reactor:each(function(entity)
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
		it("should detach every item from every entity in the reactor", function()
			local pool = Pool.new({ name = "test", type = {} })
			local reactor = SingleReactor.new(pool)
			local event = Instance.new("BindableEvent")
			local numCalled = 0

			reactor:withAttachments(function()
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

			reactor:detach()

			event:Fire()
			expect(numCalled).to.equal(0)
		end)
	end)
end

return function()
	local Attachments = require(script.Parent.Attachments)
	local Registry = require(script.Parent.Registry)
	local Matcher = require(script.Parent.Matcher)
	local t = require(script.Parent.Parent.t)

	beforeEach(function(context)
		context.registry = Registry.new({
			Test1 = t.table,
			Test2 = t.table,
			Test3 = t.table,
		})
	end)

	describe("attach", function()
		it("should attach items when an entity enters the collection", function(context)
			local registry = context.registry
			local collection = Matcher.new(registry)
				:all("Test1", "Test2"):collect()
			local event = Instance.new("BindableEvent")
			local numCalled = 0
			local holes = {}

			Attachments.attach(collection, function()
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

			for _ = 1, 50 do
				registry:multiAdd(registry:create(), {
					Test1 = {},
					Test2 = {},
				})
			end

			event:Fire()
			expect(numCalled).to.equal(50)
			numCalled = 0

			collection:each(function(entity)
				registry:remove(entity, "Test2")
			end)

			event:Fire()
			expect(numCalled).to.equal(0)

			for _, hole in ipairs(holes) do
				expect(function()
					hole.Parent = workspace
				end).to.throw()
			end
		end)

		it("should properly handle single component collections", function(context)
			local registry = context.registry
			local collection = Matcher.new(registry):all("Test1"):collect()
			local holes = {}

			Attachments.attach(collection, function()
				local hole = Instance.new("Hole")

				hole.Parent = workspace
				table.insert(holes, hole)

				return {
					hole,
				}
			end)

			for _ = 1, 50 do
				registry:add(registry:create(), "Test1", {})
			end

			collection:each(function(entity)
				registry:remove(entity, "Test1")
			end)

			for _, hole in ipairs(holes) do
				expect(function()
					hole.Parent = workspace
				end).to.throw()
			end
		end)
	end)

	describe("detach", function()
		it("should detach every item from every entity in the collection", function(context)
			local registry = context.registry
			local collection = Matcher.new(registry)
				:all("Test1", "Test2"):collect()
			local event = Instance.new("BindableEvent")
			local numCalled = 0

			Attachments.attach(collection, function()
				return {
					event.Event:Connect(function()
						numCalled += 1
					end),
				}
			end)

			for _ = 1, 50 do
				registry:multiAdd(registry:create(), {
					Test1 = {},
					Test2 = {},
				})
			end

			Attachments.detach(collection)

			event:Fire()
			expect(numCalled).to.equal(0)
		end)

		it("should properly handle single component collections", function(context)
			local registry = context.registry
			local collection = Matcher.new(registry)
				:all("Test1"):collect()
			local event = Instance.new("BindableEvent")
			local numCalled = 0

			Attachments.attach(collection, function()
				return {
					event.Event:Connect(function()
						numCalled += 1
					end),
				}
			end)

			for _ = 1, 50 do
				registry:add(registry:create(), "Test1", {})
			end

			Attachments.detach(collection)

			event:Fire()
			expect(numCalled).to.equal(0)
		end)
	end)
end

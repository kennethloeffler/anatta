return function()
	local Entity = require(script.Parent.Entity)
	local System = require(script.Parent.System)
	local t = require(script.Parent.t)

	local registry = Entity.Registry.new({
		Test1 = t.table,
		Test2 = t.table,
		Test3 = t.table,
	})

	describe("collect", function()
		it("should return a new Collection", function()
			local system = System.new(registry)
			expect(getmetatable(system:all("Test1", "Test2"):collect())).to.equal(Entity.Collection)
		end)
	end)

	describe("pure", function()
		it("should return a new PureCollection", function()
			local system = System.new(registry)

			expect(getmetatable(system:all("Test1", "Test2"):pure())).to.equal(Entity.PureCollection)
		end)
	end)

	describe("on", function()
		it("should connect to an event", function()
			local system = System.new(registry)
			local bindableEvent = Instance.new("BindableEvent")
			local fired = false

			system:on(bindableEvent.Event, function()
				fired = true
			end)

			bindableEvent:Fire()
			expect(fired).to.equal(true)
		end)

		it("should work with collection events", function()
			local system = System.new(registry)
			local collection = system:all("Test1", "Test2"):collect()
			local fired = false

			system:on(collection.added, function()
				fired = true
			end)

			registry:multiAdd(registry:create(), {
				Test1 = {},
				Test2 = {},
			})

			expect(fired).to.equal(true)
		end)
	end)

	describe("unload", function()
		it("should disconnect any listeners connected through :on and detach the collection", function()
			local system = System.new(registry)
			local collection = system:all("Test1", "Test2"):collect()
			local hole = Instance.new("Hole")
			local bindableEvent = Instance.new("BindableEvent")
			local fired = false

			system:on(bindableEvent.Event, function()
				fired = true
			end)

			collection:attach(function()
				return {
					hole,
				}
			end)

			registry:multiAdd(registry:create(), {
				Test1 = {},
				Test2 = {},
			})

			system:unload()

			bindableEvent:Fire()
			expect(fired).to.equal(false)

			expect(function()
				hole.Parent = workspace
			end).to.throw()
		end)
	end)
end

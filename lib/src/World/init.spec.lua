return function()
	local World = require(script.Parent)
	local T = require(script.Parent.Parent.Core.T)

	describe("getReactor", function()
		it("should not error when given withUpdated", function()
			local world = World.new({
				{
					name = "MyComponent",
					type = T.table,
				},
			})

			local MyComponent = world.components.MyComponent

			expect(world:getReactor({
				withUpdated = { MyComponent },
			})).to.be.ok()
		end)
	end)
end

return function()
	local Anatta = require(script.Parent)
	local T = Anatta.T

	describe("createWorld", function()
		it("should define a list of ComponentDefinitions for the world's registry", function()
			local world = Anatta.createWorld("TestWorld1", {
				{
					name = "Loooooooook",
					type = T.table,
				},
				{
					name = "Heeeeeeerree",
					type = T.table,
				},
			})

			expect(world.registry:isComponentDefined("Loooooooook")).to.equal(true)
			expect(world.registry:isComponentDefined("Heeeeeeerree")).to.equal(true)
		end)
	end)

	describe("getWorld", function()
		it("should return a world with the given namespace", function()
			local world = Anatta.createWorld("TestWorld2")

			expect(Anatta.getWorld("TestWorld2")).to.equal(world)
		end)

		it("should error if there is no world under that namespace", function()
			expect(function()
				Anatta.getWorld("ZOned")
			end).to.throw()
		end)
	end)
end

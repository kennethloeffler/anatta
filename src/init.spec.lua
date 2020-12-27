return function()
	local anattaLib = require(script.Parent)
	local Registry = require(script.Parent.Entity.Registry)
	local t = require(script.Parent.Core.TypeDefinition)

	local testSystems = script.Parent.testSystems

	describe("new", function()
		it("should create a new anatta instance", function()
			local anatta = anattaLib.new()

			expect(getmetatable(anatta)).to.equal(anattaLib)
			expect(anatta._registry).to.be.ok()
			expect(getmetatable(anatta._registry)).to.equal(Registry)
		end)
	end)

	describe("define", function()
		it("should define the components for the registry", function()
			local anatta = anattaLib.new()

			anatta:define {
				Test1 = t.none,
				Test2 = t.none,
				Test3 = t.none,
			}

			expect(function()
				anatta._registry:getPools("Test1", "Test2", "Test3")
			end).to.never.throw()
		end)
	end)

	describe("loadSystem", function()
		it("should load a system", function()
			local anatta = anattaLib.new()

			anatta:define {
				Test1 = t.none,
				Test2 = t.none,
				Test3 = t.none,
			}



			expect(function()
				for _, system in ipairs(testSystems:GetChildren()) do
					anatta:loadSystem(system)
				end
			end).to.never.throw()
		end)
	end)

	describe("loadSystemsIn", function()
	end)
end

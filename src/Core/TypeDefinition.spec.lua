return function()
	local t = require(script.Parent.TypeDefinition)

	local function ensure(typeDef)
		expect(typeDef).to.be.a("table")
		expect(typeDef.typeName).to.be.a("string")
		expect(typeDef.check).to.be.a("function")
		expect(typeDef.instanceFields).to.be.a("table")
		expect(typeDef.fields).to.be.a("table")

		return typeDef
	end

	describe("primitive", function()
		local realT = require(script.Parent.Parent.t)

		it("should make a primitive", function()
			local typeDef = ensure(t.number)

			expect(typeDef.check).to.equal(realT.number)
		end)
	end)

	describe("higherOrder", function()
		it("should handle array", function()
			local typeDef = ensure(t.array(t.number))

			expect(typeDef.check({ 1, 2, 3 })).to.equal(true)
			expect(typeDef.check({ "bad", "boy", "array" })).to.equal(false)
		end)

		it("should handle interface", function()
			local typeDef = ensure(t.interface {
				nice = t.boolean,
				types = t.number
			})

			expect(typeDef.fields.nice.check).to.be.a("function")
			expect(typeDef.fields.types.check).to.be.a("function")
			expect(typeDef.check{ nice = true, types = 2 }).to.equal(true)
			expect(typeDef.check{ nice = true, txpes = 2 }).to.equal(false)
		end)

		it("should handle nested arrays", function()
			local typeDef = ensure(t.array(t.array(t.number)))

			expect(typeDef.check({ { 1, 2, 3 } })).to.equal(true)
			expect(typeDef.check({ { "bad", "boy", "array"} })).to.equal(false)
		end)
	end)

	describe("instance", function()
		it("should handle interfaces with top-level instance fields", function()
			local typeDef = ensure(t.interface {
				instance = t.instanceOf("IntValue")
			})

			expect(typeDef.instanceFields.instance).to.equal(true)
			expect(typeDef.check{ instance = Instance.new("IntValue") }).to.equal(true)
			expect(typeDef.check{ Instance.new("Frame") }).to.equal(false)
		end)
	end)
end

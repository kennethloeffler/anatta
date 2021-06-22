return function()
	local Type = require(script.Parent.Type)
	local t = require(script.Parent.Parent.Parent.t)

	FOCUS()
	describe("new", function()
		it("should return a primitive definition for first-order functions", function()
			local ty = Type.Vector3

			expect(ty).to.be.a("table")
			expect(ty.check).to.equal(t.Vector3)
			expect(ty.typeName).to.equal("Vector3")
		end)

		it("should return a compound definition for second-order functions", function()
			local ty = Type.instanceIsA("BasePart")

			expect(ty).to.be.a("table")
			expect(ty.typeParams).to.be.a("table")
			expect(ty.typeParams[1]).to.equal("BasePart")
			expect(ty.check).to.be.a("function")
			expect(ty.typeName).to.equal("instanceIsA")
		end)

		it("should return a compound definition for second-order functions that take functions as arguments", function()
			local ty = Type.union(Type.literal("string1"), Type.literal("string2"))

			expect(ty).to.be.a("table")
			expect(ty.typeParams).to.be.a("table")
			expect(ty.check).to.be.a("function")
			expect(ty.typeName).to.equal("union")

			local typeParams = ty.typeParams
			local string1 = typeParams[1]
			local string2 = typeParams[2]

			expect(string1).to.be.a("table")
			expect(string2).to.be.a("table")
			expect(string1.check).to.be.a("function")
			expect(string2.check).to.be.a("function")
			expect(string1.typeParams[1]).to.equal("string1")
			expect(string2.typeParams[1]).to.equal("string2")
			expect(string1.typeName).to.equal("literal")
			expect(string2.typeName).to.equal("literal")
		end)
	end)

	describe("getConcreteType", function()
		it("should resolve a primitive", function()
			expect(Type.string:tryGetConcreteType()).to.equal("string")
		end)

		it("should resolve number types", function()
			expect(Type.numberMin(0):tryGetConcreteType()).to.equal("number")
		end)

		it("should resolve a strict interface into a dictionary of concrete types", function()
			local interface = Type.strictInterface({
				all = Type.Enum,
				simulacrum = Type.string,
			})
			local concreteInterface = interface:tryGetConcreteType()

			expect(concreteInterface.all).to.equal("Enum")
			expect(concreteInterface.simulacrum).to.equal("string")
		end)

		it("should resolve a strict array into an array of concrete types", function()
		end)

		it("should resolve a union when it contains uniform types", function()
			local stringUnion = Type.union(
				Type.literal("Oh"),
				Type.literal("No"),
				Type.literal("It's"),
				Type.literal("A"),
				Type.literal("Union")
			)

			expect(stringUnion:tryGetConcreteType()).to.equal("string")
		end)
	end)
end

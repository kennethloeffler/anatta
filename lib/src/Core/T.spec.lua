return function()
	local T = require(script.Parent.T)
	local t = require(script.Parent.Parent.Parent.t)

	describe("new", function()
		it("should return a primitive definition for first-order functions", function()
			local ty = T.Vector3

			expect(ty).to.be.a("table")
			expect(ty.check).to.equal(t.Vector3)
			expect(ty.typeName).to.equal("Vector3")
		end)

		it("should return a compound definition for second-order functions", function()
			local ty = T.instanceIsA("BasePart")

			expect(ty).to.be.a("table")
			expect(ty.typeParams).to.be.a("table")
			expect(ty.typeParams[1]).to.equal("BasePart")
			expect(ty.check).to.be.a("function")
			expect(ty.typeName).to.equal("instanceIsA")
		end)

		it(
			"should return a compound definition for second-order functions that take functions as arguments",
			function()
				local ty = T.union(T.literal("string1"), T.literal("string2"))

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
			end
		)
	end)

	describe("getConcreteType", function()
		it("should fail for table", function()
			local success, msg = T.table:tryGetConcreteType()

			expect(success).to.equal(false)
		end)

		it("should resolve a primitive", function()
			local _, concreteType = T.string:tryGetConcreteType()
			expect(concreteType).to.equal("string")
		end)

		it("should resolve number types", function()
			local _, concreteType = T.numberMin(0):tryGetConcreteType()
			expect(concreteType).to.equal("number")
		end)

		it("should resolve a strict interface into a dictionary of concrete types", function()
			local interface = T.strictInterface({
				all = T.Enum,
				simulacrum = T.strictInterface({
					name = T.string,
				}),
			})
			local _, concreteInterface = interface:tryGetConcreteType()

			expect(concreteInterface.all).to.equal("Enum")
			expect(concreteInterface.simulacrum).to.be.a("table")
			expect(concreteInterface.simulacrum.name).to.equal("string")
		end)

		it("should resolve a strict array into an array of concrete types", function()
			local interface = T.strictArray(T.Enum, T.strictInterface({
				name = T.string,
			}))
			local _, concreteInterface = interface:tryGetConcreteType()

			expect(concreteInterface[1]).to.equal("Enum")
			expect(concreteInterface[2]).to.be.a("table")
			expect(concreteInterface[2].name).to.equal("string")
		end)

		it("should resolve a union when it contains uniform types", function()
			local stringUnion = T.union(
				T.literal("Oh"),
				T.literal("No"),
				T.literal("It's"),
				T.literal("A"),
				T.literal("Union")
			)

			local _, concreteType = stringUnion:tryGetConcreteType()
			expect(concreteType).to.equal("string")
		end)
	end)

	describe("API", function()
		it("should throw when indexed with an invalid type name", function()
			expect(function()
				T.instanceof("Part")
			end).to.throw()
		end)

		it("should return a callable type check", function()
			local exampleInterface = T.strictInterface({
				cool = T.number,
			})

			expect(exampleInterface({
				cool = 55
			})).to.equal(true)
		end)
	end)
end

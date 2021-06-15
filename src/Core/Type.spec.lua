return function()
	local Type = require(script.Parent.Type)
	local t = require(script.Parent.Parent.Parent.t)

	it("should return a primitive definition for first-order functions", function()
		local ty = Type.Vector3

		expect(ty).to.be.a("table")
		expect(ty.check).to.equal(t.Vector3)
		expect(ty:getConcreteType()).to.equal("Vector3")
		expect(ty.typeName).to.equal("Vector3")
	end)

	it("should return a compound definition for second-order functions", function()
		local ty = Type.instanceIsA("BasePart")

		expect(ty).to.be.a("table")
		expect(ty.args).to.be.a("table")
		expect(ty.args[1]).to.equal("BasePart")
		expect(ty.check).to.be.a("function")
		expect(ty.typeName).to.equal("instanceIsA")
	end)

	it("should return a compound definition for second-order functions that take functions as arguments", function()
		local ty = Type.union(Type.literal("string1"), Type.literal("string2"))

		expect(ty).to.be.a("table")
		expect(ty.args).to.be.a("table")
		expect(ty.check).to.be.a("function")
		expect(ty.typeName).to.equal("union")

		local args = ty.args
		local string1 = args[1]
		local string2 = args[2]

		expect(string1).to.be.a("table")
		expect(string2).to.be.a("table")
		expect(string1.check).to.be.a("function")
		expect(string2.check).to.be.a("function")
		expect(string1.args[1]).to.equal("string1")
		expect(string2.args[1]).to.equal("string2")
		expect(string1.typeName).to.equal("literal")
		expect(string2.typeName).to.equal("literal")
	end)
end

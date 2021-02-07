return function()
	local createSymbol = require(script.Parent.createSymbol)

	it("should create a new symbol", function()
		local sym = createSymbol("test")

		expect(sym).to.be.a("table")
		expect(sym._symbolName).to.equal("test")
	end)

	it("should return the same symbol object for the same name", function()
		local sym1 = createSymbol("test")
		local sym2 = createSymbol("test")

		expect(sym1).to.equal(sym2)
	end)

	it("should return a table that returns the symbol's name from __tostring", function()
		local sym = createSymbol("test")

		expect(tostring(sym)).to.equal("test")
	end)

	it("should return a table that throws when a consumer tries to mutate it", function()
		local sym = createSymbol("test")

		expect(function()
			sym.x = true
		end).to.throw()
	end)

	it("should return a string from getmetable", function()
		local sym = createSymbol("test")

		expect(getmetatable(sym)).to.equal("The metatable of Symbol is locked")
	end)

	it("should throw when setmetatable is called", function()
		local sym = createSymbol("test")

		expect(function()
			setmetatable(sym, {})
		end).to.throw()
	end)
end

return function()
	local Identify = require(script.Parent.Identify)
	local ident = Identify.new("test")

	describe("GenerateRuntime", function()
		it("should generate a sequence", function()
			local lastId

			for i = 1, 5 do
				local id = ident:generateRuntime(string.char(i))

				expect(id).to.equal(lastId and lastId + 1 or id)
				lastId = id
			end
		end)
	end)

	describe("Runtime", function()
		it("should throw if the name is not associated with an identifier", function()
			expect(pcall(ident.runtime, ident, string.char(6))).to.never.equal(true)
		end)

		it("should return the correct identifier", function()
			local id = ident:generateRuntime(string.char(6))

			expect(id).to.equal(ident:runtime(string.char(6)))
		end)
	end)
end

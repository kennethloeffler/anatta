return function()
	local Identify = require(script.Parent.Identify)

	describe("new", function()
		it("should construct a new blank Identify instance with the given context and target", function()
			local ident = Identify.new("testContext", script)

			expect(ident.context).to.equal("testContext")
			expect(ident.target).to.equal(script)
			expect(ident.max).to.equal(0)
			expect(next(ident.lookup)).to.never.be.ok()
		end)
	end)

	describe("fromIntValues", function()
		local ident = Identify.new("testContext1", script)

		local folder = Instance.new("Folder")
		folder.Name = "testContext1"
		folder.Parent = script

		for i = 1, 5 do
			local val = Instance.new("IntValue")
			val.Name = string.char(i)
			val.Value = i
			val.Parent = folder
		end

		it("should load persisted identifiers from the store of IntValues", function()
			ident:fromIntValues()

			for i = 1, 5 do
				expect(ident:named(string.char(i))).to.equal(i)
			end
		end)

		it("should throw when the given context does not exist", function()
			local id = Identify.new("context", script)

			expect(pcall(id.fromIntValues, id)).to.never.equal(true)
		end)
	end)

	describe("load", function()
		local ident = Identify.new("testContext2", script)

		for i = 1, 5 do
			ident:generate(string.char(i))
		end

		it("should load the persisted identifiers", function()
			ident:save()
			ident:clear()
			ident:load()

			for i = 1, 5 do
				expect(ident:named(string.char(i))).to.equal(i)
			end
		end)
	end)

	describe("clear", function()
		local ident = Identify.new()

		it("should reset the state of the Identify instance", function()
			ident:generate("A")
			ident:generate("B")

			ident:clear()

			expect(ident.max).to.equal(0)
			expect(next(ident.lookup)).to.never.be.ok()
			expect(pcall(ident.named, ident, "A")).to.equal(false)
			expect(pcall(ident.named, ident, "B")).to.equal(false)
		end)
	end)

	describe("generate", function()
		local ident = Identify.new("testContext3", script)

		it("should generate a sequence", function()
			local lastId

			for i = 1, 5 do
				local id = ident:generate(string.char(i))

				expect(id).to.equal(lastId and lastId + 1 or id)
				lastId = id
			end
		end)

		it("should throw if the name is already associated with an identifier", function()
			ident:generate(string.char(7))

			expect(pcall(ident.generate, ident, string.char(7))).to.equal(false)
		end)
	end)

	describe("named", function()
		local ident = Identify.new("testContext4", script)

		it("should throw if the name is not associated with an identifier", function()
			expect(pcall(ident.named, ident, string.char(2))).to.equal(false)
		end)

		it("should return the correct identifier", function()
			local id = ident:generate(string.char(1))

			expect(ident:named(string.char(1))).to.equal(id)
		end)
	end)

	describe("rename", function()
		it("should change the name associated with an identifer", function()
		end)
	end)
end

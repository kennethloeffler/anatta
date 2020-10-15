return function()
	local Identity = require(script.Parent.Identity)

	describe("new", function()
		it("should construct a new blank Identity instance with the given context and target", function()
			local ident = Identity.new()

			expect(ident.max).to.equal(0)
			expect(next(ident.lookup)).to.never.be.ok()
		end)
	end)

	describe("save", function()
		it("should save identifiers and their names", function()
			local ident = Identity.new()

			for i = 1, 5 do
				ident:generate(string.char(i))
			end
			ident:save(script)

			local stringValue = script:FindFirstChild("__identify")
			expect(stringValue).to.be.ok()
		end)
	end)

	describe("tryLoad", function()
		it("should load the persisted identifiers", function()
			local ident = Identity.new(script)

			for i = 1, 5 do
				ident:generate(string.char(i))
			end

			ident:save(script)
			ident:clear()
			ident:tryLoad(script)

			for i = 1, 5 do
				expect(ident:named(string.char(i))).to.equal(i)
			end
		end)
	end)

	describe("clear", function()
		local ident = Identity.new()

		it("should reset the state of the Identity instance", function()
			ident:generate("A")
			ident:generate("B")

			ident:clear()

			expect(ident.max).to.equal(0)
			expect(next(ident.lookup)).to.never.be.ok()
			expect(function()
				ident:named("A")
			end).to.throw()
			expect(function()
				ident:named("B")
			end).to.throw()
		end)
	end)

	describe("generate", function()
		local ident = Identity.new()

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

			expect(function()
				ident:generate(string.char(7))
			end).to.throw()
		end)
	end)

	describe("named", function()
		local ident = Identity.new(script)

		it("should throw if the name is not associated with an identifier", function()
			expect(function()
				ident:named(string.char(2))
			end).to.throw()
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

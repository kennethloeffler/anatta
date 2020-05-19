local ATTRIBUTES_ENABLED = pcall(function()
	return not not script:GetAttributes()
end)

return function()
	local Identify = require(script.Parent.Identify)

	describe("new", function()
		it("should construct a new blank Identify instance with the given context and target", function()
			local ident = Identify.new("testContext", script)

			expect(ident.context).to.equal("testContext")
			expect(ident.target).to.equal(script)
			expect(ident.runtimeMax).to.equal(0)
			expect(ident.persistentMax).to.equal(0)
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

		it("should load persistent identifiers from the store of IntValues", function()
			ident:fromIntValues()

			for i = 1, 5 do
				expect(ident:persistent(string.char(i))).to.equal(i)
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
			ident:generatePersistent(string.char(i))
		end

		it("should load the stored persistent identifiers", function()
			ident:clear()
			ident:load()

			for i = 1, 5 do
				expect(ident:persistent(string.char(i))).to.equal(i)
			end
		end)
	end)

	describe("clear", function()
		local ident = Identify.new()

		it("should reset the state of the Identify instance", function()
			ident:generatePersistent("A")
			ident:generateRuntime("A")

			ident:clear()

			expect(ident.persistentMax).to.equal(0)
			expect(ident.runtimeMax).to.equal(0)
			expect(next(ident.lookup)).to.never.be.ok()
			expect(pcall(ident.runtime, ident, "A")).to.never.equal(true)
			expect(pcall(ident.persistent, ident, "A")).to.never.equal(true)
		end)
	end)

	describe("generatePersistent", function()
		local ident = Identify.new("testContext3", script)

		it("should generate a sequence", function()
			local lastId

			for i = 1, 5 do
				local id = ident:generatePersistent(string.char(i))

				expect(id).to.equal(lastId and lastId + 1 or id)
				lastId = id
			end
		end)

		it("should create IntValues or a table attribute (if enabled) under the instance's context", function()
			local name = string.char(6)
			local id = ident:generatePersistent(name)

			if ATTRIBUTES_ENABLED then
				local att = script:GetAttribute()

				expect(att).to.be.ok()
				expect(att).to.be.a("table")
				expect(att[name]).to.equal(id)
			else
				local folder = script:FindFirstChild("testContext3")

				expect(folder).to.be.ok()

				local val = folder:FindFirstChild(name)

				expect(val).to.be.ok()
				expect(val.Value).to.equal(id)
			end
		end)

		it("should throw if the name is already associated with a persistent identifier", function()
			ident:generatePersistent(string.char(7))

			expect(pcall(ident.generatePersistent, ident, string.char(7))).to.never.equal(true)
		end)
	end)

	describe("generateRuntime", function()
		local ident = Identify.new()

		it("should generate a sequence", function()
			local lastId

			for i = 1, 5 do
				local id = ident:generateRuntime(string.char(i))

				expect(id).to.equal(lastId and lastId + 1 or id)
				lastId = id
			end
		end)

		it("should throw if the name is already associated with a runtime identifier", function()
			ident:generateRuntime(string.char(6))

			expect(pcall(ident.generateRuntime, ident, string.char(6))).to.never.equal(true)
		end)
	end)

	describe("runtime", function()
		local ident = Identify.new()

		it("should throw if the name is not associated with a runtime identifier", function()
			expect(pcall(ident.runtime, ident, string.char(2))).to.never.equal(true)
		end)

		it("should return the correct runtime identifier", function()
			local id = ident:generateRuntime(string.char(1))

			expect(ident:runtime(string.char(1))).to.equal(id)
		end)
	end)

	describe("persistent", function()
		local ident = Identify.new("testContext4", script)

		it("should throw if the name is not associated with a persistent identifier", function()
			expect(pcall(ident.persistent, ident, string.char(2))).to.never.equal(true)
		end)

		it("should return the correct persistent identifier", function()
			local id = ident:generatePersistent(string.char(1))

			expect(ident:persistent(string.char(1))).to.equal(id)
		end)
	end)

	describe("rename", function()
		it("should change the name associated with an identifer", function()
		end)
	end)
end

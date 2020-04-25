return function()
	local SparseSet = require(script.Parent.SparseSet)
	local value = math.random(1, 100)


	describe("new", function()
		local set = SparseSet.new()

		it("should return a new empty sparse set", function()
			expect(set).to.be.a("table")
			expect(set.Size).to.equal(0)
			expect(next(set.External)).never.to.be.ok()
			expect(next(set.Internal)).never.to.be.ok()
		end)
	end)

	describe("Insert", function()
		it("should correctly insert a value into the set", function()
			local set = SparseSet.new()

			SparseSet.Insert(set, value)

			local index = set.External[value]

			expect(set.Size).to.equal(1)
			expect(index).to.be.ok()
			expect(value).to.equal(set.Internal[index])
		end)
	end)

	describe("Has", function()
		local set = SparseSet.new()

		it("should correctly determine if a value exists in the set", function()
			SparseSet.Insert(set, value)

			expect(SparseSet.Has(set, value)).to.be.ok()
			expect(SparseSet.Has(set, value + 1)).to.never.be.ok()
		end)

		it("should return the correct index into the internal array", function()
			expect(SparseSet.Has(set, value)).to.equal(set.External[value])
		end)
	end)

	describe("Remove", function()
		it("should correctly remove a value from the set", function()
			local set = SparseSet.new()
			local index = set.External[value]

			SparseSet.Insert(set, value)
			SparseSet.Remove(set, value)

			expect(set.Size).to.equal(0)
			expect(set.External[value]).to.equal(nil)
			expect(set.Internal[index]).to.equal(nil)
		end)

		it("should throw when the set does not contain the value", function()
			local set = SparseSet.new()

			expect(pcall(SparseSet.Remove, set, value)).to.equal(false)
		end)
	end)
end

local SparseSet = require(script.Parent.SparseSet)
local TestValue = 0xdead

return function()
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
		it("should correctly insert the value into the set", function()
			local set = SparseSet.new()

			SparseSet.Insert(set, TestValue)

			local index = set.External[TestValue]

			expect(set.Size).to.equal(1)
			expect(index).to.be.ok()
			expect(TestValue).to.equal(set.Internal[index])
		end)
	end)

	describe("Has", function()
		local set = SparseSet.new()

		it("should correctly determine if the value exists in the set", function()
			SparseSet.Insert(set, TestValue)

			expect(SparseSet.Has(set, TestValue)).to.be.ok()
			expect(SparseSet.Has(set, TestValue + 1)).to.never.be.ok()
		end)

		it("should return the correct index into the internal array", function()
			expect(SparseSet.Has(set, TestValue)).to.equal(set.External[TestValue])
		end)
	end)

	describe("Remove", function()
		it("should correctly remove the value from the set", function()
			local set = SparseSet.new()

			SparseSet.Insert(set, TestValue)

			local index = set.External[TestValue]

			SparseSet.Remove(set, TestValue)

			expect(set.Size).to.equal(0)
			expect(set.External[TestValue]).to.equal(nil)
			expect(set.Internal[index]).to.equal(nil)
		end)

		it("should throw when the set does not contain the value", function()
			local set = SparseSet.new()

			expect(pcall(SparseSet.Remove, set, TestValue)).to.equal(false)
		end)
	end)
end

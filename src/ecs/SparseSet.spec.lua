local SparseSet = require(script.Parent.SparseSet)
local TestValue = 0xdead

return function()
	describe("new", function()
		local set = SparseSet.new()

		it("should return a new empty sparse set", function()
			expect(set).to.be.a("table")
			expect(set.size).to.equal(0)
			expect(next(set.external)).never.to.be.ok()
			expect(next(set.internal)).never.to.be.ok()
		end)
	end)

	describe("Insert", function()
		it("should correctly insert the value into the set", function()
			local set = SparseSet.new()

			SparseSet.insert(set, TestValue)

			local index = set.external[TestValue]

			expect(set.size).to.equal(1)
			expect(index).to.be.ok()
			expect(TestValue).to.equal(set.internal[index])
		end)
	end)

	describe("Has", function()
		local set = SparseSet.new()

		it("should correctly determine if the value exists in the set", function()
			SparseSet.insert(set, TestValue)

			expect(SparseSet.has(set, TestValue)).to.be.ok()
			expect(SparseSet.has(set, TestValue + 1)).to.never.be.ok()
		end)

		it("should return the correct index into the internal array", function()
			expect(SparseSet.has(set, TestValue)).to.equal(set.external[TestValue])
		end)
	end)

	describe("Remove", function()
		it("should correctly remove the value from the set", function()
			local set = SparseSet.new()

			SparseSet.insert(set, TestValue)

			local index = set.external[TestValue]

			SparseSet.remove(set, TestValue)

			expect(set.size).to.equal(0)
			expect(set.external[TestValue]).to.equal(nil)
			expect(set.internal[index]).to.equal(nil)
		end)

		it("should throw when the set does not contain the value", function()
			local set = SparseSet.new()

			expect(pcall(SparseSet.remove, set, TestValue)).to.equal(false)
		end)
	end)
end

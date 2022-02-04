return function()
	local T = require(script.Parent.Parent.Core.T)
	local waitForRefs = require(script.Parent.waitForRefs)

	it("should return an empty table when the type definition contains no refs", function()
		local ty = T.strictInterface({
			field1 = T.number,
			field2 = T.Vector3,
		})

		local refs = waitForRefs(Instance.new("Folder"), "Test", ty)

		expect(refs).to.be.a("table")
		expect(next(refs)).to.equal(nil)
	end)
end

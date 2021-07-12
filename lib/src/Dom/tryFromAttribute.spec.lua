return function()
	local t = require(script.Parent.Parent.Core.Type)

	local tryFromAttribute = require(script.Parent.tryFromAttribute)

	describe("basic types", function()
		it(
			"should return true and the value when the instance has the correct attribute",
			function()
				local instance = Instance.new("Folder")

				instance:SetAttribute("Test", Vector3.new(1, 1, 1))

				local success, result = tryFromAttribute(instance, "Test", t.Vector3)
				expect(success).to.equal(true)
				expect(result).to.equal(Vector3.new(1, 1, 1))
			end
		)

		it("should return false for an unresolvable type", function()
			local instance = Instance.new("Folder")
			local success, result = tryFromAttribute(instance, "Test", t.Random)

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)

		it("should return false when the attribute is not of the correct type", function()
			local instance = Instance.new("Hole")

			instance:SetAttribute("Test", 2.7182818284)

			local success, result = tryFromAttribute(instance, "Test", t.Vector3)
			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)

		it("should return false when the instance does not have the attribute", function()
			local success, result = tryFromAttribute(Instance.new("Hole"), "Test", t.Vector3)
			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)
	end)

	describe("strictInterface", function()
		it(
			"should return true and the value when the instance has the correct attributes",
			function()
				local instance = Instance.new("Folder")
				instance:SetAttribute("Test_Field1", UDim2.new(1, 2, 3, 4))
				instance:SetAttribute("Test_Field2", true)
				instance:SetAttribute("Test_Field3", -273.15)

				local success, result = tryFromAttribute(
					instance,
					"Test",
					t.strictInterface({
						Field1 = t.UDim2,
						Field2 = t.boolean,
						Field3 = t.number,
					})
				)

				expect(success).to.equal(true)
				expect(result).to.be.a("table")
				expect(result.Field1).to.equal(UDim2.new(1, 2, 3, 4))
				expect(result.Field2).to.equal(true)
				expect(result.Field3).to.equal(-273.15)
			end
		)
	end)
end

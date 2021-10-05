return function()
	local Constants = require(script.Parent.Parent.Core.Constants)
	local t = require(script.Parent.Parent.Core.TypeDefinition)

	local INSTANCE_REF_FOLDER = Constants.InstanceRefFolder

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

	describe("Instance", function()
		it(
			"should resolve a true boolean attribute to a an Instance reference contained by a correspondingly-named ObjectValue under the ref folder",
			function()
				local instanceWithAttribute = Instance.new("FlagStand")
				local refFolder = Instance.new("Folder")
				local objectValue = Instance.new("ObjectValue")
				local part = Instance.new("Part")

				refFolder.Name = INSTANCE_REF_FOLDER
				refFolder.Parent = instanceWithAttribute

				objectValue.Value = part
				objectValue.Name = "Test"
				objectValue.Parent = refFolder

				instanceWithAttribute:SetAttribute("Test", true)

				local success, result = tryFromAttribute(instanceWithAttribute, "Test", t.Instance)

				expect(success).to.equal(true)
				expect(result).to.equal(part)
			end
		)

		it("should fail when the ObjectValue does not exist", function()
			local instanceWithAttribute = Instance.new("FlagStand")
			local refFolder = Instance.new("Folder")

			refFolder.Name = INSTANCE_REF_FOLDER
			refFolder.Parent = instanceWithAttribute

			instanceWithAttribute:SetAttribute("Test", true)

			local success, result = tryFromAttribute(instanceWithAttribute, "Test", t.Instance)

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)

		it("should fail when the ref folder does not exist", function()
			local instanceWithAttribute = Instance.new("FlagStand")

			instanceWithAttribute:SetAttribute("Test", true)

			local success, result = tryFromAttribute(instanceWithAttribute, "Test", t.Instance)

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)

		it("should fail when the attribute is false", function()
			local instanceWithAttribute = Instance.new("FlagStand")

			instanceWithAttribute:SetAttribute("Test", false)

			local success, result = tryFromAttribute(instanceWithAttribute, "Test", t.Instance)

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)
	end)

	describe("instanceOf", function()
		it("should fail when the referent is not of the correct class", function()
			local instanceWithAttribute = Instance.new("FlagStand")
			local refFolder = Instance.new("Folder")
			local objectValue = Instance.new("ObjectValue")
			local hole = Instance.new("Hole")

			refFolder.Name = INSTANCE_REF_FOLDER
			refFolder.Parent = instanceWithAttribute

			objectValue.Value = hole
			objectValue.Name = "Test"
			objectValue.Parent = refFolder

			instanceWithAttribute:SetAttribute("Test", true)

			local success, result = tryFromAttribute(
				instanceWithAttribute,
				"Test",
				t.instanceOf("Part")
			)

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)
	end)

	describe("instanceIsA", function()
		it("should fail when the referent is not of the correct kind", function()
			local instanceWithAttribute = Instance.new("FlagStand")
			local refFolder = Instance.new("Folder")
			local objectValue = Instance.new("ObjectValue")
			local hole = Instance.new("Hole")

			refFolder.Name = INSTANCE_REF_FOLDER
			refFolder.Parent = instanceWithAttribute

			objectValue.Value = hole
			objectValue.Name = "Test"
			objectValue.Parent = refFolder

			instanceWithAttribute:SetAttribute("Test", true)

			local success, result = tryFromAttribute(
				instanceWithAttribute,
				"Test",
				t.instanceIsA("BasePart")
			)

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)
	end)
end

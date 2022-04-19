return function()
	local CollectionService = game:GetService("CollectionService")
	local Constants = require(script.Parent.Parent.Core.Constants)
	local T = require(script.Parent.Parent.Core.T)

	local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
	local INSTANCE_REF_FOLDER = Constants.InstanceRefFolder

	local tryFromAttributes = require(script.Parent.tryFromAttributes)

	describe("basic types", function()
		it("should return true and the value when the instance has the correct attribute", function()
			local instance = Instance.new("Folder")

			instance:SetAttribute("Test", Vector3.new(1, 1, 1))
			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)

			local success, entity, component = tryFromAttributes(instance, {
				name = "Test",
				type = T.Vector3,
			})

			expect(success).to.equal(true)
			expect(component).to.equal(Vector3.new(1, 1, 1))
			expect(entity).to.equal(1)
		end)

		it("should fail for an unresolvable type", function()
			local instance = Instance.new("Folder")

			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)

			local success, result = tryFromAttributes(instance, {
				name = "Test",
				type = T.Random,
			})

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)

		it("should fail when the attribute is not of the correct type", function()
			local instance = Instance.new("Hole")

			instance:SetAttribute("Test", 2.7182818284)
			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)

			local success, result = tryFromAttributes(instance, {
				name = "Test",
				type = T.Vector3,
			})
			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)

		it("should fail when the instance does not have the attribute", function()
			local instance = Instance.new("Hole")

			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)

			local success, result = tryFromAttributes(instance, {
				name = "Test",
				type = T.Vector3,
			})

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)
	end)

	describe("none", function()
		it("should return true when the instance has the correct tag", function()
			local instance = Instance.new("Folder")

			CollectionService:AddTag(instance, "Test")
			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 0)

			local success = tryFromAttributes(instance, { name = "Test", type = T.none })

			expect(success).to.equal(true)
		end)
	end)

	describe("strictInterface", function()
		it("should return true and the value when the instance has the correct attributes", function()
			local instance = Instance.new("Folder")

			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)
			instance:SetAttribute("Test_Field1", UDim2.new(1, 2, 3, 4))
			instance:SetAttribute("Test_Field2", true)
			instance:SetAttribute("Test_Field3", -273.15)

			local success, entity, component = tryFromAttributes(instance, {
				name = "Test",
				type = T.strictInterface({
					Field1 = T.UDim2,
					Field2 = T.boolean,
					Field3 = T.number,
				}),
			})

			expect(success).to.equal(true)
			expect(entity).to.equal(1)
			expect(component).to.be.a("table")
			expect(component.Field1).to.equal(UDim2.new(1, 2, 3, 4))
			expect(component.Field2).to.equal(true)
			expect(component.Field3).to.equal(-273.15)
		end)
	end)

	describe("array", function()
		it("should return true and an array containing the values of the appropriate attributes", function()
			local instance = Instance.new("Folder")

			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)
			instance:SetAttribute("Test_1_my", "influence")
			instance:SetAttribute("Test_1_is", "maximal")
			instance:SetAttribute("Test_2_my", "presence")
			instance:SetAttribute("Test_2_is", "everywhere")
			instance:SetAttribute("Test_3_my", "name")
			instance:SetAttribute("Test_3_is", "God")

			local success, entity, component = tryFromAttributes(instance, {
				name = "Test",
				type = T.array(T.strictInterface({
					my = T.string,
					is = T.string,
				})),
			})

			expect(success).to.equal(true)
			expect(entity).to.equal(1)
			expect(component).to.be.a("table")
			expect(component[1]).to.be.a("table")
			expect(component[2]).to.be.a("table")
			expect(component[3]).to.be.a("table")
			expect(component[1].my).to.equal("influence")
			expect(component[1].is).to.equal("maximal")
			expect(component[2].my).to.equal("presence")
			expect(component[2].is).to.equal("everywhere")
			expect(component[3].my).to.equal("name")
			expect(component[3].is).to.equal("God")
		end)
	end)

	describe("strictArray", function()
		it("should return true and the value when the instance has the correct attributes", function()
			local instance = Instance.new("Folder")

			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)
			instance:SetAttribute("Test_1", UDim2.new(1, 2, 3, 4))
			instance:SetAttribute("Test_2", true)
			instance:SetAttribute("Test_3", -273.15)

			local success, entity, component = tryFromAttributes(instance, {
				name = "Test",
				type = T.strictArray(T.UDim2, T.boolean, T.number),
			})

			expect(success).to.equal(true)
			expect(entity).to.equal(1)
			expect(component).to.be.a("table")
			expect(component[1]).to.equal(UDim2.new(1, 2, 3, 4))
			expect(component[2]).to.equal(true)
			expect(component[3]).to.equal(-273.15)
		end)
	end)

	describe("Instance", function()
		it(
			"should resolve a true boolean attribute to a an Instance reference contained by a correspondingly-named ObjectValue under the ref folder",
			function()
				local instance = Instance.new("FlagStand")
				local refFolder = Instance.new("Folder")
				local objectValue = Instance.new("ObjectValue")
				local part = Instance.new("Part")

				refFolder.Name = INSTANCE_REF_FOLDER
				refFolder.Parent = instance

				objectValue.Value = part
				objectValue.Name = "Test"
				objectValue.Parent = refFolder

				instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)
				instance:SetAttribute("Test", true)

				local success, entity, component = tryFromAttributes(instance, {
					name = "Test",
					type = T.Instance,
				})

				expect(success).to.equal(true)
				expect(entity).to.equal(1)
				expect(component).to.equal(part)
			end
		)

		it("should fail when the ObjectValue does not exist", function()
			local instance = Instance.new("FlagStand")
			local refFolder = Instance.new("Folder")

			refFolder.Name = INSTANCE_REF_FOLDER
			refFolder.Parent = instance

			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)
			instance:SetAttribute("Test", true)

			local success, result = tryFromAttributes(instance, {
				name = "Test",
				type = T.Instance,
			})

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)

		it("should fail when the ref folder does not exist", function()
			local instance = Instance.new("FlagStand")

			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)
			instance:SetAttribute("Test", true)

			local success, result = tryFromAttributes(instance, {
				name = "Test",
				type = T.Instance,
			})

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)

		it("should fail when the attribute is false", function()
			local instance = Instance.new("FlagStand")

			instance:SetAttribute("Test", false)
			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)

			local success, result = tryFromAttributes(instance, {
				name = "Test",
				type = T.Instance,
			})

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)
	end)

	describe("instanceOf", function()
		it("should fail when the referent is not of the correct class", function()
			local instance = Instance.new("FlagStand")
			local refFolder = Instance.new("Folder")
			local objectValue = Instance.new("ObjectValue")
			local hole = Instance.new("Hole")

			refFolder.Name = INSTANCE_REF_FOLDER
			refFolder.Parent = instance

			objectValue.Value = hole
			objectValue.Name = "Test"
			objectValue.Parent = refFolder

			instance:SetAttribute("Test", true)
			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)

			local success, result = tryFromAttributes(instance, {
				name = "Test",
				type = T.instanceOf("Part"),
			})

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)
	end)

	describe("instanceIsA", function()
		it("should fail when the referent is not of the correct kind", function()
			local instance = Instance.new("FlagStand")
			local refFolder = Instance.new("Folder")
			local objectValue = Instance.new("ObjectValue")
			local hole = Instance.new("Hole")

			refFolder.Name = INSTANCE_REF_FOLDER
			refFolder.Parent = instance

			objectValue.Value = hole
			objectValue.Name = "Test"
			objectValue.Parent = refFolder

			instance:SetAttribute("Test", true)
			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, 1)

			local success, result = tryFromAttributes(instance, {
				name = "Test",
				type = T.instanceIsA("BasePart"),
			})

			expect(success).to.equal(false)
			expect(result).to.be.a("string")
		end)
	end)
end

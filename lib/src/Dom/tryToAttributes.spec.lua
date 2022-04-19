return function()
	local T = require(script.Parent.Parent.Core.T)

	local tryToAttributes = require(script.Parent.tryToAttributes)

	describe("T.array", function()
		it("should serialize an array", function()
			local instance = Instance.new("Folder")
			local definition = {
				name = "Test",
				type = T.array(T.strictInterface({
					this = T.number,
				})),
			}

			local success, attributeMap = tryToAttributes(instance, 0, definition, {
				{ this = 1 },
				{ this = 2 },
				{ this = 3 },
				{ this = 4 },
			})

			expect(success).to.equal(true)
			expect(attributeMap.Test_1_this).to.equal(1)
			expect(attributeMap.Test_2_this).to.equal(2)
			expect(attributeMap.Test_3_this).to.equal(3)
			expect(attributeMap.Test_4_this).to.equal(4)
		end)
	end)
end

return function()
	local Signal = require(script.Parent.Signal)

	describe("new", function()
		it("should create a new signal object", function()
			local sig = Signal.new()

			expect(sig.Listeners).to.be.ok()
			expect(type(sig.Listeners)).to.equal("table")
			expect(#sig).to.equal(0)
		end)
	end)

	describe("Connect", function()
		it("should insert a callback into .Listeners", function()
			local sig = Signal.new()

			local callback = function()
			end

			sig:Connect(callback)

			expect(sig.Listeners[1]).to.equal(callback)
		end)
	end)

	describe("Dispatch", function()
		it("should call every callback in .Listeners with the correct parameters", function()
			local sig = Signal.new()
			local num = 0

			for _ = 1, 5 do
				sig:Connect(function(add)
					num = num + add
				end)
			end

			sig:Dispatch(1)

			expect(num).to.equal(5)
		end)
	end)
end

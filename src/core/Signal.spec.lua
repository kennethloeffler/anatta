return function()
	local Signal = require(script.Parent.Signal)

	FOCUS()

	describe("new", function()
		it("should create a new signal object", function()
			local sig = Signal.new()

			expect(sig.Callbacks).to.be.ok()
			expect(type(sig.Callbacks)).to.equal("table")
			expect(#sig.Callbacks).to.equal(0)

			expect(sig.Connections).to.be.ok()
			expect(type(sig.Connections)).to.equal("table")
			expect(#sig.Connections).to.equal(0)
		end)
	end)

	describe("Connect", function()
		it("should insert a callback into .Callbacks", function()
			local sig = Signal.new()

			local callback = function() end

			sig:Connect(callback)

			expect(sig.Callbacks[1]).to.equal(callback)
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

	describe("Disconnect", function()
		it("should remove a callback from .Callbacks", function()
			local sig = Signal.new()
			local callback = function() end
			local con = sig:Connect(callback)

			con:Disconnect()

			expect(#sig.Callbacks).to.equal(0)
		end)
	end)
end

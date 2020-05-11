local Signal = require(script.Parent.Signal)

return function()
	describe("new", function()
		it("should create a new signal object", function()
			local sig = Signal.new()

			expect(sig.callbacks).to.be.ok()
			expect(type(sig.callbacks)).to.equal("table")
			expect(#sig.callbacks).to.equal(0)

			expect(sig.connections).to.be.ok()
			expect(type(sig.connections)).to.equal("table")
			expect(#sig.connections).to.equal(0)
		end)
	end)

	describe("Connect", function()
		it("should insert a callback into .callbacks", function()
			local sig = Signal.new()

			local callback = function() end

			sig:connect(callback)

			expect(sig.callbacks[1]).to.equal(callback)
		end)
	end)

	describe("Dispatch", function()
		it("should call every callback in .listeners with the correct parameters", function()
			local sig = Signal.new()
			local num = 0

			for _ = 1, 5 do
				sig:connect(function(add)
					num = num + add
				end)
			end

			sig:dispatch(1)
			expect(num).to.equal(5)
		end)
	end)

	describe("Disconnect", function()
		it("should remove a callback from .callbacks", function()
			local sig = Signal.new()
			local callback = function() end
			local con = sig:connect(callback)

			con:disconnect()

			expect(#sig.callbacks).to.equal(0)
		end)
	end)
end

return function()
	local Signal = require(script.Parent.Signal)

	describe("new", function()
		it("should create a new signal object", function()
			local sig = Signal.new()

			expect(sig.callbacks).to.be.ok()
			expect(type(sig.callbacks)).to.equal("table")
			expect(#sig.callbacks).to.equal(0)
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
			local disconnect = sig:connect(callback)

			disconnect()

			expect(#sig.callbacks).to.equal(0)
		end)

		itFOCUS("should not mess up an ongoing dispatch", function()
			local sig = Signal.new()
			local first = false
			local second = false
			local third = false
			local disconnect

			disconnect = sig:connect(function()
				first = true
				disconnect()
			end)

			sig:connect(function()
				second = true
			end)

			sig:connect(function()
				third = true
			end)

			sig:dispatch()

			expect(first and second and third).to.equal(true)
		end)
	end)
end

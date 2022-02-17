return function()
	local Signal = require(script.Parent.Signal)

	describe("new", function()
		it("should create a new Signal", function()
			local sig = Signal.new()

			expect(sig._callbacks).to.be.a("table")
			expect(next(sig._callbacks)).to.equal(nil)
			expect(sig._disconnected).to.be.a("table")
			expect(next(sig._callbacks)).to.equal(nil)
		end)
	end)

	describe("Connect", function()
		it("should insert a callback into .callbacks", function()
			local sig = Signal.new()

			local callback = function() end

			sig:connect(callback)

			expect(sig._callbacks[1]).to.equal(callback)
		end)

		it("should not invalidate an ongoing dispatch", function()
			local sig = Signal.new()
			local inner = false
			local outer = false

			sig:connect(function()
				outer = true
				sig:connect(function()
					inner = true
				end)
			end)

			sig:dispatch()
			expect(outer).to.equal(true)
			expect(inner).to.equal(false)

			sig:dispatch()
			expect(outer).to.equal(true)
			expect(inner).to.equal(true)
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
			local connection = sig:connect(callback)

			connection:disconnect()

			expect(#sig._callbacks).to.equal(0)
		end)

		it("should not invalidate an ongoing dispatch", function()
			local sig = Signal.new()
			local first = false
			local second = false
			local third = false
			local connection

			connection = sig:connect(function()
				first = true
				connection:disconnect()
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

		it("should cause the callback to not be called during a dispatch", function()
			local sig = Signal.new()
			local never = false
			local connection

			sig:connect(function()
				connection:disconnect()
			end)

			connection = sig:connect(function()
				never = true
			end)

			sig:dispatch()

			expect(never).to.never.equal(true)
		end)
	end)
end

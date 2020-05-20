-- teensy weensy signal implementation, take it or leave it

local Signal = {}
Signal.__index = Signal

--[[

 Construct and return new signal object

]]
function Signal.new()
	return setmetatable({
		callbacks = {},
		disconnected = {}
	}, Signal)
end

--[[

 Add a function to be called whenever Signal::Dispatch is called

]]
function Signal:connect(callback)
	local callbacks = self.callbacks

	table.insert(callbacks, callback)
	self.disconnected[callback] = nil

	return function()
		local new = {}
		local size = 0

		for _, oldCallback in ipairs(callbacks) do
			if oldCallback ~= callback then
				size = size + 1
				new[size] = oldCallback
			end
		end

		self.callbacks = new
	end
end

--[[

 Call all of the connected functions

 Function calls are guaranteed to be in the same order they were
 connected in.

]]
function Signal:dispatch(...)
	local disconnected = self.disconnected

	for _, callback in ipairs(self.callbacks) do
		if not disconnected[callback] then
			callback(...)
		else
			disconnected[callback] = nil
		end
	end
end

return Signal

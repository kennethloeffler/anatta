local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		callbacks = {},
		disconnected = {}
	}, Signal)
end

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

Signal.Connect = Signal.connect

function Signal:dispatch(...)
	local disconnected = self.disconnected

	for _, callback in ipairs(self.callbacks) do
		if not disconnected[callback] then
			coroutine.wrap(callback)(...)
		else
			disconnected[callback] = nil
		end
	end
end

Signal.Fire = Signal.dispatch

return Signal

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		Listeners = {}
	}, Signal)
end

function Signal:Connect(callback)
	table.insert(self.Listeners, callback)
end

function Signal:Dispatch(...)
	local listeners = self.Listeners

	for i, callback in ipairs(listeners) do
		callback(...)
		listeners[i] = nil
	end
end

return Signal

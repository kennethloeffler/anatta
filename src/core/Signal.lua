local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection.new(signal)
	return setmetatable({
		Signal = signal
	}, Connection)
end

function Connection:Disconnect()
	local signal = self.Signal

	table.remove(signal.Callbacks, signal.Connections[self])
end

function Signal.new()
	return setmetatable({
		Callbacks = {},
		Connections = {}
	}, Signal)
end

function Signal:Connect(callback)
	local connection = Connection.new(self)

	table.insert(self.Callbacks, callback)
	self.Connections[connection] = #self.Callbacks

	return connection
end

function Signal:Dispatch(...)
	local callbacks = self.Callbacks

	for _, callback in ipairs(callbacks) do
		callback(...)
	end
end

return Signal

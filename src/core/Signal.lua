local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection.new(signal)
	return setmetatable({
		signal = signal
	}, Connection)
end

function Connection:disconnect()
	local signal = self.signal
	local connections = signal.connections
	local index = connections[self]

	-- disconnecting n callbacks will be O(n^2), but if n is large in
	-- this case, listeners are not the solution to your problem
	-- anyway
	table.remove(signal.callbacks, index)

	for con, idx in pairs(connections) do
		if idx > index then
			connections[con] = index - 1
		end
	end
end

function Signal.new()
	return setmetatable({
		callbacks = {},
		connections = {}
	}, Signal)
end

function Signal:connect(callback)
	local connection = Connection.new(self)

	table.insert(self.callbacks, callback)
	self.connections[connection] = #self.callbacks

	return connection
end

function Signal:dispatch(...)
	local callbacks = self.callbacks

	for _, callback in ipairs(callbacks) do
		callback(...)
	end
end

return Signal

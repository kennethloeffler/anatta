local Signal = {}
Signal.__index = Signal

local function append(list, element)
	local len = #list
	local newList = table.create(#list + 1)

	table.move(list, 1, len, 1, newList)
	table.insert(newList, element)

	return newList
end

function Signal.new()
	return setmetatable({
		_callbacks = {},
		_disconnected = {},
	}, Signal)
end

function Signal:connect(callback)
	self._callbacks = append(self._callbacks, callback)

	local function disconnect()
		local newList = {}
		local i = 0

		for _, oldCallback in ipairs(self._callbacks) do
			if oldCallback ~= callback then
				i += 1
				newList[i] = oldCallback
			end
		end

		self._disconnected[callback] = true
		self._callbacks = newList
	end

	return {
		disconnect = disconnect,
		Disconnect = disconnect,
	}
end

Signal.Connect = Signal.connect

function Signal:dispatch(...)
	local disconnected = self._disconnected

	for _, callback in ipairs(self._callbacks) do
		if not disconnected[callback] then
			task.spawn(callback, ...)
		else
			disconnected[callback] = nil
		end
	end
end

Signal.Fire = Signal.dispatch

return Signal

local SingleSelector = {}
SingleSelector.__index = SingleSelector

function SingleSelector.new(pool)
	return  setmetatable({
		_pool = pool
	}, SingleSelector)
end

function SingleSelector:entities(callback)
	local dense = self._pool.dense

	for i = self._pool.size, 1, -1 do
		callback(dense[i])
	end
end

function SingleSelector:each(callback)
	local dense = self._pool.dense
	local objects = self._pool.objects

	for i = self._pool.size, 1, -1 do
		callback(dense[i], objects[i])
	end
end

function SingleSelector:onAdded(callback)
	return self._pool.onAdd:connect(callback)
end

function SingleSelector:onRemoved(callback)
	return self._pool.onRemove:connect(callback)
end

return SingleSelector

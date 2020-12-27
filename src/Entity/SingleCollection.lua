local SingleCollection = {}
SingleCollection.__index = SingleCollection

function SingleCollection.new(pool)
	return  setmetatable({
		_pool = pool
	}, SingleCollection)
end

function SingleCollection:entities(callback)
	local dense = self._pool.dense

	for i = self._pool.size, 1, -1 do
		callback(dense[i])
	end
end

function SingleCollection:each(callback)
	local dense = self._pool.dense
	local objects = self._pool.objects

	for i = self._pool.size, 1, -1 do
		callback(dense[i], objects[i])
	end
end

function SingleCollection:onAdded(callback)
	return self._pool.onAdd:connect(callback)
end

function SingleCollection:onRemoved(callback)
	return self._pool.onRemove:connect(callback)
end

return SingleCollection

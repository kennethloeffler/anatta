local SingleCollection = {}
SingleCollection.__index = SingleCollection

function SingleCollection.new(pool)
	return  setmetatable({
		onAdded = pool.onAdded,
		onRemoved = pool.onRemoved,

		_pool = pool,
	}, SingleCollection)
end

function SingleCollection:each(callback)
	local dense = self._pool.dense
	local objects = self._pool.objects

	for i = self._pool.size, 1, -1 do
		callback(dense[i], objects[i])
	end
end

return SingleCollection

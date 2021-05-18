local SinglePureCollection = {}
SinglePureCollection.__index = SinglePureCollection

function SinglePureCollection.new(pool)
	return setmetatable({
		_pool = pool,
	}, SinglePureCollection)
end

function SinglePureCollection:each(callback)
	local objects = self._pool.objects

	for i, entity in ipairs(self._pool.dense) do
		objects[i] = callback(entity, objects[i])
	end
end

return SinglePureCollection

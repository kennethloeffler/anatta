local SinglePureCollection = {}
SinglePureCollection.__index = SinglePureCollection

function SinglePureCollection.new(pool)
	return setmetatable({
		_pool = pool,
	}, SinglePureCollection)
end

function SinglePureCollection:each(callback)
	local components = self._pool.components

	for i, entity in ipairs(self._pool.dense) do
		components[i] = callback(entity, components[i])
	end
end

return SinglePureCollection

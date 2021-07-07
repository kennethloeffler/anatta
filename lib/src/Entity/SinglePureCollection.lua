local SinglePureCollection = {}
SinglePureCollection.__index = SinglePureCollection

function SinglePureCollection.new(pool)
	return setmetatable({
		_pool = pool,
	}, SinglePureCollection)
end

function SinglePureCollection:update(callback)
	local components = self._pool.components
	local updated = self._pool.updated

	for i, entity in ipairs(self._pool.dense) do
		local oldComponent = components[i]
		local newComponent = callback(entity, oldComponent)

		if newComponent ~= oldComponent then
			updated:dispatch(entity, newComponent)
			components[i] = newComponent
		end
	end
end

function SinglePureCollection:each(callback)
	local components = self._pool.components

	for i, entity in ipairs(self._pool.dense) do
		callback(entity, components[i])
	end
end

return SinglePureCollection

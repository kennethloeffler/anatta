local SingleMapper = {}
SingleMapper.__index = SingleMapper

function SingleMapper.new(pool)
	return setmetatable({
		_pool = pool,
	}, SingleMapper)
end

function SingleMapper:update(callback)
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

function SingleMapper:each(callback)
	local components = self._pool.components

	for i, entity in ipairs(self._pool.dense) do
		callback(entity, components[i])
	end
end

return SingleMapper

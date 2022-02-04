local SingleMapper = {}
SingleMapper.__index = SingleMapper

function SingleMapper.new(pool)
	return setmetatable({
		_pool = pool,
	}, SingleMapper)
end

function SingleMapper:find(callback)
	local components = self._pool.components

	for i, entity in ipairs(self._pool.dense) do
		local result = callback(entity, components[i])

		if result ~= nil then
			return result
		end
	end

	return nil
end

function SingleMapper:filter(callback)
	local results = {}
	local components = self._pool.components

	for i, entity in ipairs(self._pool.dense) do
		local result = callback(entity, components[i])

		if result ~= nil then
			table.insert(results, result)
		end
	end

	return results
end

function SingleMapper:map(callback)
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

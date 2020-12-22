local SingleReducer = {}
SingleReducer.__index = SingleReducer

function SingleReducer.new(pool)
	return setmetatable({
		_pool = pool
	}, SingleReducer)
end

function SingleReducer:entities(callback)
	for _, entity in ipairs(self._pool.dense) do
		callback(entity)
	end
end

function SingleReducer:each(callback)
	local objects = self._pool.objects

	for i, entity in ipairs(self._pool.dense) do
		objects[i] = callback(entity, objects[i])
	end
end

return SingleReducer

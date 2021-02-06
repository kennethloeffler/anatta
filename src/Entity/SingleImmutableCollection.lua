local SingleImmutableCollection = {}
SingleImmutableCollection.__index = SingleImmutableCollection

function SingleImmutableCollection.new(pool)
	return setmetatable({
		_pool = pool
	}, SingleImmutableCollection)
end

function SingleImmutableCollection:each(callback)
	local objects = self._pool.objects

	for i, entity in ipairs(self._pool.dense) do
		objects[i] = callback(entity, objects[i])
	end
end

return SingleImmutableCollection

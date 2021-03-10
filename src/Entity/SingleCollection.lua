local SingleCollection = {}
SingleCollection.__index = SingleCollection

function SingleCollection.new(componentPool)
	return  setmetatable({
		added = componentPool.added,
		removed = componentPool.removed,

		_componentPool = componentPool,
	}, SingleCollection)
end

function SingleCollection:each(callback)
	local dense = self._componentPool.dense
	local objects = self._componentPool.objects

	for i = self._componentPool.size, 1, -1 do
		callback(dense[i], objects[i])
	end
end

return SingleCollection

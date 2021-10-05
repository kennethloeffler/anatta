local Finalizers = require(script.Parent.Parent.Core.Finalizers)
local Pool = require(script.Parent.Parent.Core.Pool)

local SingleCollection = {}
SingleCollection.__index = SingleCollection

function SingleCollection.new(componentPool)
	return setmetatable({
		added = componentPool.added,
		removed = componentPool.removed,

		_pool = false,
		_connections = {},
		_componentPool = componentPool,
	}, SingleCollection)
end

function SingleCollection:each(callback)
	local dense = self._componentPool.dense
	local components = self._componentPool.components

	for i = self._componentPool.size, 1, -1 do
		callback(dense[i], components[i])
	end
end

function SingleCollection:attach(callback)
	if not self._pool then
		self._pool = Pool.new("collectionInternal", {})
	end

	table.insert(
		self._connections,
		self.added:connect(function(entity, component)
			self._pool:insert(entity, callback(entity, component))
		end)
	)

	table.insert(
		self._connections,
		self.removed:connect(function(entity)
			for _, item in ipairs(self._pool:get(entity)) do
				Finalizers[typeof(item)](item)
			end
		end)
	)
end

function SingleCollection:detach()
	if not self._pool then
		return
	end

	for _, item in ipairs(self._pool.components) do
		for _, attached in ipairs(item) do
			Finalizers[typeof(attached)](attached)
		end
	end

	for _, connection in ipairs(self._connections) do
		connection:disconnect()
	end
end

return SingleCollection

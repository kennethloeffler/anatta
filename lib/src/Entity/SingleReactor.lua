local Finalizers = require(script.Parent.Parent.Core.Finalizers)
local Pool = require(script.Parent.Parent.Core.Pool)

local SingleReactor = {}
SingleReactor.__index = SingleReactor

function SingleReactor.new(componentPool)
	return setmetatable({
		added = componentPool.added,
		removed = componentPool.removed,

		_pool = false,
		_connections = {},
		_componentPool = componentPool,
	}, SingleReactor)
end

function SingleReactor:each(callback)
	local dense = self._componentPool.dense
	local components = self._componentPool.components

	for i = self._componentPool.size, 1, -1 do
		callback(dense[i], components[i])
	end
end

function SingleReactor:attach(callback)
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

function SingleReactor:detach()
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

return SingleReactor

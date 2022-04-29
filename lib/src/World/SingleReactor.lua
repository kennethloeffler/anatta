local Finalizers = require(script.Parent.Parent.Core.Finalizers)
local Pool = require(script.Parent.Parent.Core.Pool)
local Types = require(script.Parent.Parent.Types)

local ErrBadAttachmentTable = "function at %s:%i returned a bad attachment table: %s"

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

function SingleReactor:find(callback)
	local dense = self._componentPool.dense
	local components = self._componentPool.components

	for i = self._componentPool.size, 1, -1 do
		local result = callback(dense[i], components[i])

		if result ~= nil then
			return result
		end
	end

	return nil
end

function SingleReactor:filter(callback)
	local results = {}
	local dense = self._componentPool.dense
	local components = self._componentPool.components

	for i = self._componentPool.size, 1, -1 do
		local result = callback(dense[i], components[i])

		if result ~= nil then
			table.insert(results, result)
		end
	end

	return results
end

function SingleReactor:withAttachments(callback)
	if not self._pool then
		self._pool = Pool.new({ name = "ReactorInternalPool", type = {} })
	end

	table.insert(
		self._connections,
		self.added:connect(function(entity, component)
			local attachments = callback(entity, component)
			local success, err = Types.AttachmentTable(attachments)

			if not success then
				error(ErrBadAttachmentTable:format(debug.info(callback, "s"), debug.info(callback, "l"), err), 2)
			end

			self._pool:insert(entity, attachments)
		end)
	)

	table.insert(
		self._connections,
		self.removed:connect(function(entity)
			local attachments = self._pool:get(entity)

			if attachments == nil then
				-- Tried to double remove (removeComponent inside the callback)? We don't really care...
				return
			end

			for _, attachment in pairs(attachments) do
				Finalizers[typeof(attachment)](attachment)
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

local Pool = require(script.Parent.Parent.Core.Pool)

local function disconnect(item)
	item:Disconnect()
end

local finalizers = {
	RBXScriptConnection = disconnect,
	table = disconnect,
	Instance = game.Destroy,
}

local function attach(collection, callback)
	local function insert(entity, ...)
		collection._pool:replace(entity, callback(entity, ...))
	end

	local function delete(entity)
		for _, item in ipairs(collection._pool:get(entity)) do
			finalizers[typeof(item)](item)
		end
	end

	if not next(collection._pool) then
		collection._pool = Pool.new()

		insert = function(entity, component)
			collection._pool:insert(entity, callback(entity, component))
		end

		delete = function(entity)
			for _, item in ipairs(collection._pool:get(entity)) do
				finalizers[typeof(item)](item)
			end

			collection._pool:delete(entity)
		end
	end

	table.insert(collection._connections, collection.added:connect(insert))
	table.insert(collection._connections, collection.removed:connect(delete))
end

local function detach(collection)
	if not collection or not next(collection._pool) then
		return
	end

	local objects = collection._pool.objects
	local removed = collection.removed
	local numPacked = collection._numPacked
	local packed = collection._packed
	local singleComponents = not packed and collection._componentPool.objects

	if packed then
		for i, entity in ipairs(collection._pool.dense) do
			for _, attached in ipairs(objects[i]) do
				finalizers[typeof(attached)](attached)
			end

			collection:_pack(entity)
			removed:dispatch(entity, unpack(packed, 1, numPacked))
		end
	else
		for i, entity in ipairs(collection._pool.dense) do
			for _, attached in ipairs(objects[i]) do
				finalizers[typeof(attached)](attached)
			end

			removed:dispatch(entity, singleComponents[i])
		end
	end

	for _, connection in ipairs(collection._connections) do
		connection:disconnect()
	end
end

return {
	attach = attach,
	detach = detach,
}

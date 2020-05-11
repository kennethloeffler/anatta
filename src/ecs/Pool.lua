local Signal = require(script.Parent.Parent.core.Signal)
local SparseSet = require(script.Parent.SparseSet)

local remove = SparseSet.remove
local insert = SparseSet.insert
local has = SparseSet.has

local Pool = {}

Pool.has = has

function Pool.new(dataType, capacity)
	local pool = SparseSet.new(capacity)

	if dataType then
		pool.objects = {} -- table.create(capacity or 0)
		pool.type = dataType
	end

	pool.onAssign = Signal.new()
	pool.onRemove = Signal.new()
	pool.onUpdate = Signal.new()

	return pool
end

function Pool.get(pool, entity)
	local index = has(pool, entity)
	local objects = pool.objects

	if objects and index then
		return objects[index]
	end
end

function Pool.assign(pool, entity, object)
	local size = insert(pool, entity)

	if pool.objects then
		pool.objects[size] = object

		return object
	end
end

function Pool.destroy(pool, entity)
	local objects = pool.objects
	local size = pool.size
	local index = remove(pool, entity)

	-- component type could be empty
	if objects then
		if size > 1 then
			objects[index] = objects[size]
		end

		objects[size] = nil
	end
end

return Pool

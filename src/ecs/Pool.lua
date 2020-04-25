local Signal = require(script.Parent.Parent.core.Signal)
local SparseSet = require(script.Parent.SparseSet)

local remove = SparseSet.Remove
local insert = SparseSet.Insert
local has = SparseSet.Has

local Pool = {}

Pool.Has = has

function Pool.new(dataType, capacity)
	local pool = SparseSet.new(capacity)

	if dataType then
		pool.Objects = {} -- table.create(capacity or 0)
		pool.Type = dataType
	end

	pool.OnAssign = Signal.new()
	pool.OnRemove = Signal.new()
	pool.OnUpdate = Signal.new()

	return pool
end

function Pool.Get(pool, entity)
	local index = has(pool, entity)
	local objects = pool.Objects

	if objects and index then
		return objects[index]
	end
end

function Pool.Assign(pool, entity, object)
	insert(pool, entity)

	if pool.Objects then
		table.insert(pool.Objects, object)

		return object
	end
end

function Pool.Destroy(pool, entity)
	local objects = pool.Objects
	local size = pool.Size - 1
	local index = remove(pool, entity)

	-- component type could be empty
	if objects then
		objects[index] = size ~= 0 and table.remove(objects) or nil
	end
end

return Pool

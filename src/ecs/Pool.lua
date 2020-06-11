local Signal = require(script.Parent.Parent.core.Signal)
local SparseSet = require(script.Parent.SparseSet)

local remove = SparseSet.remove
local insert = SparseSet.insert
local has = SparseSet.has

local Pool = {}

Pool.__tostring = function(pool)
	return pool.name
end

Pool.has = has

function Pool.new(name, dataType, capacity)
	local pool = SparseSet.new(capacity)

	if dataType then
		pool.objects = {} -- table.create(capacity or 0)
		pool.type = dataType
	end

	pool.name = name

	pool.onAssign = Signal.new()
	pool.onRemove = Signal.new()
	pool.onReplace = Signal.new()

	return setmetatable(pool, Pool)
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

	if objects then
		if index < size then
			objects[index] = objects[size]
		end

		objects[size] = nil
	end
end

function Pool.clear(pool)
	local internal = pool.internal
	local external = pool.external
	local objects = pool.objects

	if objects then
		for i, entity in ipairs(pool.internal) do
			internal[i] = nil
			external[entity] = nil
			objects[i] = nil
		end
	else
		for i, entity in ipairs(pool.internal) do
			internal[i] = nil
			external[entity] = nil
		end
	end
end

return Pool

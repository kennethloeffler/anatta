local Snapshot = {}
Snapshot.__index = Snapshot


function writeSize(container, size)
	local t = table.create and table.create(size) or {}

	container[#container + 1] = t

	return t
end

function writeEntity(container, entity)
	table.insert(container, entity)
end

local move

if not table.move then
	move = function(t1, f, e, t, t2)
		for i = f, e do
			t2[t] = t1[i]
			t = t + 1
		end

		return t2
	end
else
	move = table.move
end

function Snapshot.new(source, lastDestroyed, getNextDestroyed)
	return setmetatable({
		source = source,
		lastDestroyed = lastDestroyed,
		getNextDestroyed = getNextDestroyed
	}, Snapshot)
end

function Snapshot:entities(container)
	local manifest = self.source
	local write = container.writeEntity or writeEntity
	local size = container.writeSize or writeSize
	local cont = size(container, manifest:numEntities())

	manifest:forEach(function(entity)
		write(cont, entity)
	end)

	return self
end

function Snapshot:destroyed(container)
	local manifest = self.source
	local numDestroyed  = manifest.size - manifest:numEntities()
	local getNext = self.getNextDestroyed
	local write = container.writeEntity or writeEntity
	local size = container.writeSize or writeSize
	local cont = size(container, numDestroyed)
	local curr

	if numDestroyed > 0 then
		curr = self.lastDestroyed
		write(cont, curr)

		for _ = 1, numDestroyed - 1 do
			curr = getNext(curr)
			write(cont, curr)
		end
	end

	return self
end

function Snapshot:components(container, ...)
	local manifest = self.source
	local size = container.writeSize or writeSize
	local cont
	local instances
	local write
	local pool
	local poolSize

	for _, componentId in ipairs({ ... }) do
		write = container.writeComponent and container.WriteComponent[componentId] or move
		pool = manifest.pools[componentId]
		instances = pool.objects
		poolSize = pool.size
		cont = size(container, poolSize)

		if not instances then
			write(pool.internal, 1, poolSize, 1, cont)
		else
			write(pool.internal, 1, poolSize, 1, cont)
			cont = size(container, poolSize)
			write(instances, 1, poolSize, 1, cont)
		end
	end

	return self
end

return Snapshot

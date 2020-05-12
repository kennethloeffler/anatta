local Snapshot = {}
Snapshot.__index = Snapshot

local writeSize
local writeEntity
local writeComponents

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
	local write
	local pool

	for _, componentId in ipairs({ ... }) do
		write = container.writeComponents
			and container.writeComponents[componentId]
			or writeComponents
		pool = manifest:_getPool(componentId)

		write(container, pool.size, pool.internal, pool.objects)
	end

	return self
end

writeSize = function(container, size)
	local t = table.create and table.create(size) or {}

	container[#container + 1] = t

	return t
end

writeEntity = function(container, entity)
	table.insert(container, entity)
end

do
	local move = table.move
		and table.move
		or function(t1, f, e, t, t2)
				for i = f, e do
					t2[t] = t1[i]
					t = t + 1
					return t2
				end
		   end

	writeComponents = function(container, size, entities, components)
		local siz = container.writeSize or writeSize

		move(entities, 1, size, 1, siz(container, size))
		move(components, 1, size, 1, siz(container, size))
	end
end

return Snapshot

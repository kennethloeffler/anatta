local Snapshot = {}
Snapshot.__index = Snapshot

local writeSize
local move
local writeComponents

function Snapshot.new(source)
	return setmetatable({
		source = source
	}, Snapshot)
end

function Snapshot:entities(destination)
	local manifest = self.source
	local write = destination.writeEntity
	local size = destination.writeSize or writeSize
	local cont = size(destination, manifest:numEntities())

	if not write then
		move(manifest.entities, 1, manifest.size, 1, cont)
	else
		for _, entity in ipairs(manifest.entities) do
			write(cont, entity)
		end
	end

	return self
end

function Snapshot:components(container, ...)
	local manifest = self.source
	local writeFuncs = container.writeComponents
	local write = container.writeComponents
	local pool

	for _, componentId in ipairs({ ... }) do
		write = writeFuncs and writeFuncs[componentId] or writeComponents
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

move = table.move
	and table.move
	or function(t1, f, e, t, t2)
		for i = f, e do
			t2[t] = t1[i]
			t = t + 1
		end
		return t2
	   end

writeComponents = function(container, size, entities, components)
	local write = container.writeSize or writeSize

	move(entities, 1, size, 1, write(container, size))

	if components then
		move(components, 1, size, 1, write(container, size))
	end
end

return Snapshot

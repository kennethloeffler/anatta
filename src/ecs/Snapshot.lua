local Snapshot = {}
Snapshot.__index = Snapshot

function Snapshot.new(source, lastDestroyed, getNextDestroyed)
	return setmetatable({
		Source = source,
		LastDestroyed = lastDestroyed,
		GetNextDestroyed = getNextDestroyed
	}, Snapshot)
end

function Snapshot:Entities(container)
	local manifest = self.Source

	container:Size(manifest:NumEntities())

	manifest:ForEach(function(entity)
		container:Entity(entity)
	end)

	return self
end

function Snapshot:Destroyed(container)
	local manifest = self.Source
	local numDestroyed  = manifest.Size - manifest:NumEntities()
	local getNext = self.GetNextDestroyed
	local curr

	container:Size(numDestroyed)

	if numDestroyed > 0 then
		curr = self.LastDestroyed
		container:Destroyed(curr)

		for _ = 1, numDestroyed do
			curr = getNext(curr)
			container:Entity(curr)
		end
	end

	return self
end

function Snapshot:Components(container, ...)
	local manifest = self.Source
	local instances
	local serialize

	for _, componentId in ipairs({ ... }) do
		instances = manifest.Pools[componentId].Objects
		serialize = getmetatable(container)[componentId]

		if not instances then
			-- don't try to pass instance because this is an empty component
			-- type which doesn't have any instances
			for _, entity in ipairs(manifest.Pools[componentId].Internal) do
				serialize(container, entity)
			end
		else
			for index, entity in ipairs(manifest.Pools[componentId].Internal) do
				serialize(container, entity, instances[index])
			end
		end
	end

	return self
end

return Snapshot

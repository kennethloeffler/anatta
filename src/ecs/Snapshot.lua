local Snapshot = {}
Snapshot.__index = Snapshot

function Snapshot.new(source, lastDestroyed, getNextDestroyed)
	return setmetatable({
		Source = source,
		LastDestroyed = lastDestroyed,
		GetNextDestroyed = getNextDestroyed
	}, Snapshot)
end


function Snapshot:Entities(destination)
	local manifest = self.Source

	destination:Size(manifest:NumEntities())

	manifest:ForEach(function(entity)
		destination:Entity(entity)
	end)

	return self
end

function Snapshot:Destroyed(destination)
	local manifest = self.Source
	local numDestroyed  = manifest.Size - manifest:NumEntities()
	local getNext = self.GetNextDestroyed
	local curr

	destination:Size(numDestroyed)

	if numDestroyed > 0 then
		curr = self.LastDestroyed
		destination:Destroyed(curr)

		for _ = 1, numDestroyed do
			curr = getNext(curr)
			destination:Entity(curr)
		end
	end

	return self
end

function Snapshot:Components(destination)
end

return Snapshot

local Snapshot = {}
Snapshot.__index = Snapshot

function Snapshot.new(source, init)
	return setmetatable({
		Source = source,
		InitEntity = init
	}, Snapshot)
end

return Snapshot

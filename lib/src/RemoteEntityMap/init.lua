local withSharedInstances = require(script.withSharedInstances)

local RemoteEntityMap = {}
RemoteEntityMap.__index = RemoteEntityMap

function RemoteEntityMap.new(registry)
	return setmetatable({
		registry = registry,
		localEntitiesByRemote = {},
		remoteEntitiesByLocal = {},
	}, RemoteEntityMap)
end

function RemoteEntityMap:add(remoteEntity)
	local localEntity = self.registry:create()

	self.remoteEntitiesByLocal[localEntity] = remoteEntity
	self.localEntitiesByRemote[remoteEntity] = localEntity

	return localEntity
end

function RemoteEntityMap:remove(remoteEntity)
	local localEntity = self.localEntitiesByRemote[remoteEntity]

	self.registry:destroy(localEntity)
	self.remoteEntitiesByLocal[localEntity] = nil
	self.localEntitiesByRemote[remoteEntity] = nil
end

function RemoteEntityMap:getLocal(remoteEntity)
	return self.localEntitiesByRemote[remoteEntity]
end

function RemoteEntityMap:getRemote(localEntity)
	return self.remoteEntitiesByLocal[localEntity]
end

function RemoteEntityMap:withSharedInstances()
	withSharedInstances(self)
end

return RemoteEntityMap

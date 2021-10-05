local withSharedInstances = require(script.withSharedInstances)

local RemoteEntityMap = {}
RemoteEntityMap.__index = RemoteEntityMap

function RemoteEntityMap.new(registry)
	return setmetatable({
		registry = registry,
		remoteFromLocal = {},
		localFromRemote = {},
	}, RemoteEntityMap)
end

function RemoteEntityMap:add(remoteEntity)
	local localEntity = self.registry:create()

	self.remoteFromLocal[localEntity] = remoteEntity
	self.localFromRemote[remoteEntity] = localEntity

	return localEntity
end

function RemoteEntityMap:remove(remoteEntity)
	local localEntity = self.localFromRemote[remoteEntity]

	self.registry:destroy(localEntity)
	self.remoteFromLocal[localEntity] = nil
	self.localFromRemote[remoteEntity] = nil
end

function RemoteEntityMap:getLocalEntity(remoteEntity)
	return self.localFromRemote[remoteEntity]
end

function RemoteEntityMap:getRemoteEntity(localEntity)
	return self.remoteFromLocal[localEntity]
end

function RemoteEntityMap:withSharedInstances()
	withSharedInstances(self)
end

return RemoteEntityMap

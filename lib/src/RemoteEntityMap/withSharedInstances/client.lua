local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Parent.Core.Constants)
local Dom = require(script.Parent.Parent.Parent.Dom)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local SHARED_INSTANCE_TAG_NAME = Constants.SharedInstanceTagName

return function(remoteEntityMap)
	local registry = remoteEntityMap.registry
	local sharedInstances = CollectionService:GetTagged(SHARED_INSTANCE_TAG_NAME)
	local connectedListeners = {}

	local function adorn(localEntity, sharedInstance)
		local connections = {}

		for _, componentName in ipairs(CollectionService:GetTags(sharedInstance)) do
			if not registry:hasDefined(componentName) then
				continue
			end

			local typeDefinition = registry:getDefinition(componentName)
			local objectValues = Dom.waitForRefs(sharedInstance, componentName, typeDefinition)

			for _, objectValue in ipairs(objectValues) do
				if objectValue.Value == sharedInstance then
					-- If the reference is to the shared Instance, then it is definitely
					-- valid right now. It will remain valid at least until the shared
					-- Instance is removed (whether by tag removal, being streamed out,
					-- destruction, etc.), so nothing more must be done in this case.
					continue
				end

				-- Otherwise, this ObjectValue must be observed to ensure that the
				-- Registry never contains an invalid reference.
				table.insert(
					connections,
					objectValue.Changed:Connect(function(ref)
						if ref == nil then
							registry:tryRemove(localEntity, componentName)
						else
							local success, component = Dom.tryFromAttribute(
								sharedInstance,
								componentName,
								typeDefinition
							)

							if success then
								registry:tryAdd(localEntity, componentName, component)
							end
						end
					end)
				)
			end

			connectedListeners[sharedInstance] = connections

			local _, component = Dom.tryFromAttribute(sharedInstance, componentName, typeDefinition)

			registry:tryAdd(localEntity, componentName, component)
		end
	end

	for _, sharedInstance in ipairs(sharedInstances) do
		local remoteEntity = sharedInstance:GetAttribute(ENTITY_ATTRIBUTE_NAME)
		local localEntity = remoteEntityMap:add(remoteEntity)

		task.defer(adorn, localEntity, sharedInstance)
	end

	-- Both of these connections will leak after a hot reload, but it's probably ok?

	CollectionService
		:GetInstanceAddedSignal(SHARED_INSTANCE_TAG_NAME)
		:Connect(function(sharedInstance)
			local remoteEntity = sharedInstance:GetAttribute(ENTITY_ATTRIBUTE_NAME)
			local localEntity = remoteEntityMap:add(remoteEntity)

			adorn(localEntity, sharedInstance)
		end)

	CollectionService
		:GetInstanceRemovedSignal(SHARED_INSTANCE_TAG_NAME)
		:Connect(function(sharedInstance)
			local remoteEntity = sharedInstance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

			remoteEntityMap:remove(remoteEntity)

			for _, connection in ipairs(connectedListeners[sharedInstance]) do
				connection:Disconnect()
			end
		end)
end

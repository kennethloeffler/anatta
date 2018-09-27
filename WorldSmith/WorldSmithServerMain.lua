local CollectionService = game:GetService("CollectionService")
local WorldObjectInfo = require(game.ServerScriptService.WorldSmith.WorldObjectInfo)

local function createArgDictionary(paramContainerChildren)
	local t = {}
	local c = paramContainerChildren
	for i, v in ipairs(c) do
		if v:IsA("ValueBase") then
			t[v.Name] = v.Value
		end
	end
	return t
end

local WorldSmithMain = {}
WorldSmithMain.__index = WorldSmithMain

function WorldSmithMain.new()
	local instance = setmetatable({}, WorldSmithMain)
	
	local assignedInstances = CollectionService:GetTagged("WorldObject")
	for _, obj in pairs(assignedInstances) do
		for _, paramContainer in pairs(obj:GetChildren()) do
			if paramContainer:IsA("Folder") then
				local paramContainerChildren = paramContainer:GetChildren()
				if WorldObjectInfo[paramContainer.Name]._connectEventsFunction ~= nil then
					WorldObjectInfo[paramContainer.Name]._connectEventsFunction(createArgDictionary(paramContainerChildren), paramContainer)
				end
			end
		end
	end
	
	return instance
end

return WorldSmithMain.new()
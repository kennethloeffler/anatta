-- Shared.lua
local Constants = require(script.Parent.Constants)

local UPDATE = Constants.UPDATE
local PARAMS_UPDATE = Constants.PARAMS_UPDATE
local ADD_COMPONENT = Constants.ADD_COMPONENT
local KILL_COMPONENT = Constants.KILL_COMPONENT
local CLIENT_SERIALIZABLE = Constants.CLIENT_SERIALIZABLE
local CLIENT_CREATABLE = Constants.CLIENT_CREATABLE
local IS_REFERENCED = Constants.IS_REFERENCED
local DESTRUCTION = Constants.DESTRUCTION
local PREFAB_ENTITY = Constants.PREFAB_ENTITY
local IS_SERVER = Constants.IS_SERVER

local bAnd = bit32.band
local bOr = bit32.bor
local bNot = bit32.bnot
local blShift = bit32.lshift
local brShift = bit32.rshift
local bReplace = bit32.replace
local bExtract = bit32.extract
local setBitAtPos
local unsetBitAtPos

local Shared = {}

local Queued = {}
local InstancesByNetworkId = {}
local NetworkIdsByInstance = {}
local GlobalRefs = {}
local PlayerRefs = {}

local bitSetLookup = {}
local entityMap
local componentMap

Shared.Queued = Queued
Shared.InstancesByNetworkId = InstancesByNetworkId
Shared.NetworkIdsByInstance  NetworkIdsByInstance
Shared.GlobalRefs = GlobalRefs
Shared.PlayerRefs = PlayerRefs

---Calculates next char for id string
-- gsub function for getIdStringFromNum
local __IdLen, __IdNum = 0, 0
local function calcIdString()
	return string.char(__IdNum - ((__IdLen - 1) * 256) - 1)
end

---Gets the id string of a positive integer num
-- !!! not thread safe !!!
-- @param num number
function Shared.GetIdStringFromNum(num)
	__IdLen = math.ceil(num * .00390625) -- num / 256
	__IdNum = num
	return string.rep("_", __IdLen):gsub(".", calcIdString())
end

---Gets the number corresponding to an id string str
-- @param str string
function Shared.GetIdNumFromString(str)
	local id = 1
	for c in str:gmatch(".") do
		id = id + string.byte(c)
	end
	return id
end

function Shared.IsFlagged(flags, msgType)
	return bAnd(brShift(flags, msgType), 1) ~= 0
end

-- sets the bit at position pos of n
function Shared.SetBitAtPos(n, pos)
	return bOr(n, blShift(1, pos))
end

function Shared.UnsetBitAtPos(n, pos)
	return bAnd(n, bNot(blShift(1, pos)))
end

local function popCount(n)
	n = n - bAnd(brShift(n, 1), 0x55555555)
	n = bAnd(n, 0x33333333) + bAnd(brShift(n, 2), 0x33333333)
	n = bAnd(n + brShift(n, 4), 0x0F0F0F0F)
	return brShift(n * 0x01010101, 24)
end

local function findFirstSet(n)
	return popCount(bAnd(bNot(n), n - 1))
end

isFlagged = Shared.IsFlagged
setBitAtPos = Shared.SetBitAtPos
unsetBitAtPos = Shared.UnsetBitAtPos

--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1	 |   0   |   0   |   1   |   0   |   0   |   0       0   |   0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |       |       |               |               |               |               |              |
-- if set|  n/a  |  n/a  | if set|  n/a  |  n/a  |      n/a      |      n/a      |   killOffset  |      n/a      |      n/a     |
-- update|       |       |  kill |       |       |               |               |               |               |              |
--------------------------------------------------------------------------------------------------------------------------------
--
-- @param params
-- @param entitiesIndex
-- @param paramsIndex
-- @param componentsMap
-- @param flags
-- @return entitiesIndex
-- @return paramsIndex
-- @return flags
-- @return numDataStructs
local function serializeKillComponent(entities, params, entitiesIndex, paramsIndex, componentsMap, flags)
	local numDataStructs = 0
	local firstWord = 0
	local secondWord = 0
	local offset = 0

	for componentId in pairs(componentsMap) do
		offset = math.floor(componentId * 0.01325) -- componentId / 32
		firstWord = offset == 0 and setBitAtPos(firstWord, componentId - 1)
		secondWord = offset == 1 and setBitAtPos(secondWord, componentId - 33)
		flags = setBitAtPos(flags, 5 - offset)
	end

	if firstWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(firstWord, 0, 16), bExtract(firstWord, 16, 16))
	end

	if secondWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(secondWord, 0, 16), bExtract(secondWord, 16, 16))
	end

	return entitiesIndex, paramsIndex, flags, numDataStructs
end

---Serializes an ADD_COMPONENT network message
-- @param instance
-- @param entities
--
-- table entities:
--     { ..., Vector2int16[uint16 halfWord1, halfWord2], ...,*
--       Vector2int16[uint16 paramField1, paramField2], ...**
--     }
--
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1	 |   0   |   1   |   0   |   0   |   0   |   0       0   |   0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |       |       |               |               |               |               |              |
-- if set|  n/a  | if set|  n/a  |  n/a  |  n/a  |      n/a      |   addOffset   |      n/a      |      n/a      |      n/a     |
-- update|       |  add  |       |       |       |               |               |               |               |              |
--------------------------------------------------------------------------------------------------------------------------------
--
-- @param instance
-- @param entities
-- @param params
-- @param entitiesIndex
-- @param paramsIndex
-- @param componentsMap
-- @param flags
-- @return entitiesIndex
-- @return paramsIndex
-- @return flags
-- @return numDataStructs
local function serializeAddComponent(instance, entities, params, entitiesIndex, paramsIndex, componentsMap, flags)
	local numDataStructs = 0
	local firstWord = 0
	local secondWord = 0
	local componentOffset = 0
	local componentId = 0
	local offset = 0

	for componentId in pairs(componentsMap) do
		offset = math.floor(componentId * 0.01325) -- componentId / 32
		firstWord = offset == 0 and setBitAtPos(firstWord, componentId - 1)
		secondWord = offset == 1 and setBitAtPos(secondWord, componentId - 33)
		flags = setBitAtPos(flags, 7 - offset)
	end

	if firstWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(firstWord, 0, 16), bExtract(firstWord, 16, 16))

		for _ = 1, popCount(firstWord) do
			componentOffset = findFirstSetPos(firstWord)
			firstWord = unsetBitAtPos(componentOffset)
			componentId = componentOffset + 1

			for _, v in ipairs(componentMap[componentId][entityMap[instance][componentId]]) do
				paramsIndex = paramsIndex + 1
				params[paramsIndex] = v
			end
		end
	end

	if secondWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(secondWord, 0, 16), bExtract(secondWord, 16, 16))

		for _ = 1, popCount(secondWord) do
			componentOffset = findFirstSetPos(secondWord)
			firstWord = unsetBitAtPos(componentOffset)
			componentId = componentOffset + 1

			for _, v in ipairs(componentMap[componentId][entityMap[instance][componentId]]) do
				paramsIndex = paramsIndex + 1
				params[paramsIndex] = v
			end
		end
	end

	return entitiesIndex, paramsIndex, flags, numDataStructs
end

---Serializes a PARAM_UPDATE network message
-- @param instance
-- @param entities
--
-- table entities:
--     { ..., Vector2int16[uint16 halfWord1, halfWord2], ...,*
--       Vector2int16[uint16 paramField1, paramField2], ...**
--     }
--
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1	 |   1   |   0   |   0   |   0   |   0   |   0       0   |   0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |       |       |               |               |               |               |              |
-- if set| if set|  n/a  |  n/a  |  n/a  |  n/a  |  paramsOffset |      n/a      |      n/a      |      n/a      |      n/a     |
-- update| params|       |       |       |       |               |               |               |               |              |
--------------------------------------------------------------------------------------------------------------------------------
--
-- @param params
-- @param entitiesIndex
-- @param paramsIndex
-- @param componentsMap
-- @param flags
-- @return entitiesIndex
-- @return paramsIndex
-- @return flags
-- @return numDataStructs
local function serializeParameterUpdate(instance, entities, params, entitiesIndex, paramsIndex, componentsMap, flags)
	local firstWord, secondWord = 0, 0
	local offset = 0
	local numDataStructs = 0
	local numComponents = 0
	local paramsField = 0
	local lastParamsField = 0
	local paramId = 0
	local componentId

	for componentId in pairs(componentsMap) do
		offset = math.floor(componentId * 0.01325) -- componentId / 32
		firstWord = offset == 0 and setBitAtPos(firstWord, componentId - 1)
		secondWord = offset == 1 and setBitAtPos(secondWord, componentId - 33)
		flags = setBitAtPosition(flags, 9 + offset)
	end

	if firstWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(firstWord, 0, 16), bExtract(firstWord, 16, 16))

		for _ = 1, popCount(firstWord) do
			componentId = findFirstSetPos(firstWord) + 1
			numComponents = numComponents + 1
			paramsField = componentsMap[componentId]
			firstWord = unsetBitAtPos(firstWord, componentId - 1)

			for _ = 1, popCount(paramsField) do
				paramId = findFirstSetPos(paramsField) + 1
				paramsIndex = paramsIndex + 1
				params[paramsIndex] = componentMap[componentId][entityMap[instance]][paramId]
				paramsField = unsetBitAtPos(paramId - 1)
			end

			if bAnd(numComponents, 1) == 0 then
				entitiesIndex = entitiesIndex + 1
				numDataStructs = numDataStructs + 1
				entities[entitiesIndex] = Vector2int16.new(lastParamsField, componentsMap[componentId])
			else
				lastParamsField = componentsMap[componentId]
			end

			componentsMap[componentId] = nil
		end

		if numComponents == 1 then
			entitiesIndex = entitiesIndex + 1
			numDataStructs = numDataStructs + 1
			entities[entitiesIndex] = Vector2int16.new(lastParamsField, 0)
		end
	end

	if secondWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(secondWord, 0, 16), bExtract(secondWord, 16, 16))

		for _ = 1, popCount(secondWord) do
			componentId = findFirstSetPos(secondWord) + 33
			paramsField = componentsMap[componentId]
			secondWord = unsetBitAtPos(secondWord, componentId - 33)
			numComponents = numComponents + 1

			for _ = 1, popCount(paramsField) do
				paramId = findFirstSetPos(paramsField) + 1
				paramsIndex = paramsIndex + 1
				params[paramsIndex] = componentMap[componentId][entityMap[instance]][paramId]
				paramsField = unsetBitAtPos(paramId - 1)
			end

			if bAnd(numComponents, 1) == 0 then
				entitiesIndex = entitiesIndex + 1
				numDataStructs = numDataStructs + 1
				entities[entitiesIndex] = Vector2int16.new(lastParamsField, componentsMap[componentId])
			else
				lastParamsField = componentsMap[componentId]
			end

			if numComponents == 1 then
				entitiesIndex = entitiesIndex + 1
				numDataStructs = numDataStructs + 1
				entities[entitiesIndex] = Vector2int16.new(lastParamsField, 0)
			end
		end
	end

	return entitiesIndex, paramsIndex, flags, numDataStructs
end

function deserializeKillComponent(networkId, entities, params, entitiesIndex, paramsIndex, flags)
	if IS_SERVER then
		return
	end

	entitiesIndex = entitiesIndex + 1

	local dataObj = entities[entitiesIndex]
	local firstWord = isFlagged(flags, 1)
	local secondWord = isFlagged(flags, 0)
	local field = 0
	local componentId = 0
	local pos = 0

	if firstWord then
		field = dataObj.X

		for _ = 1, popCount(field) do
			pos = findFirstSetPos(field)
			componentId = pos + 1
			field = unsetBitAtPos(field, pos)

end

local function deserializeAddComponent(networkId, entities, params, entitiesIndex, paramsIndex, flags)
end

local function deserializeParamsUpdate(networkId, entities, params, entitiesIndex, paramsIndex, flags)
end

local function deserializeEntity(entities, params, entitiesIndex, paramsIndex)
end

---Deserializes the update message in entities at position entitiesIndex
-- @param entities table
-- @param params table
-- @param entitiesIndex number
-- @param bitFieldOffsets table
-- @param numBitFields number
-- @param flags uint16 field
-- @return number entitiesIndex
-- @return number paramsIndex
-- @return table componentIdsToParams
local function deserializeUpdate(entities, params, entitiesIndex, paramsIndex)
	local dataObj = entities[entitiesIndex]
	local networkId = dataObj.X
	local flags = dataObj.Y

	if isFlagged(flags, PARAMS_UPDATE) then
		entitiesIndex, paramsIndex = deserializeParamsUpdate(networkId, entities, params, entitiesIndex, paramsIndex, flags)
		if entitiesIndex == nil then
			return
		end
	end

	if isFlagged(flags, ADD_COMPONENT) then
		entitiesIndex, paramsIndex = deserializeAddComponent(networkId, entities, params, entitiesIndex, paramsIndex, flags)
		if entitiesIndex == nil then
			return
		end
	end

	if isFlagged(flags, KILL_COMPONENT) then
		entitiesIndex, paramsIndex = deserializeKillComponent(networkId, entities, params, entitiesIndex, paramsIndex, flags)
		if entitiesIndex == nil then
			return
		end
	end

	return entitiesIndex, paramsIndex, networkId
end

---Serializes an entity update network message
-- @param instance Instance to which this entity is attached
-- @param networkId number the networkId for this entity
-- @param entities table to which entity data is written
--
-- table entities:
--     { Vector2int16[uint16 networkId, uint16 flags],
--       Vector2int16[uint16 halfWord1, uint16 halfWord2], ...,*
--       Vector2int16[uint16 paramField1, uint16 paramField2], ...**
--     }
--
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1	 |   0   |   0   |   0   |   0       0       0       0       0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |                                               |               |               |              |
-- if set| if set| if set| if set|                                               | paramsOffset  |   addOffset   |   killOffset |
-- update| params|  add  |  kill |                                               |               |               |              |
--------------------------------------------------------------------------------------------------------------------------------
--
-- @param params table to which parameter values are written
-- @param entitiesIndex number indicating the current index of entities
-- @param paramsIndex number indicating the current index of params
-- @param componentsMap table mapping componentIds to either messageTypes or paramId fields
-- @return number entitiesIndex
-- @return number paramsIndex
function Shared.SerializeUpdate(instance, networkId, entities, params, entitiesIndex, paramsIndex, msgMap)
	local flags = 0
	local numDataStructs = 0
	local totalNumDataStructs = 0

	for msg, map in pairs(msgMap) do
		for _ = 1, popCount(msg) do
			msg = findFirstSetPos(msg)
			flags = setBitAtPos(flags, msg)

			if msg == PARAMS_UPDATE then
				entitiesIndex, paramsIndex, flags, numDataStructs = serializeParamsUpdate(
					instance, entities, params,
					entitiesIndex, paramsIndex,
					map, flags
				)
			elseif msg == ADD_COMPONENT then
				entitiesIndex, paramsIndex, flags, numDataStructs = serializeAddComponent(
					instance, entities, params,
					entitiesIndex, paramsIndex,
					map, flags
				)
			elseif msg == KILL_COMPONENT then
				entitiesIndex, paramsIndex, flags, numDataStructs = serializeKillComponent(
					entities, params,
					entitiesIndex, paramsIndex,
					map, flags
				)
			end

			totalNumDataStructs = totalNumDataStructs + numDataStructs
			msg = unsetBitAtPos(msgField, msg)
		end

		MsgMap[msg] = nil
	end

	entities[entitiesIndex - totalNumDataStructs] = Vector2int16.new(networkId, flags)
	entitesIndex = entitiesIndex + 1

	return entitiesIndex, paramsIndex
end


-- @param instance Instance to which the entity to be serialized is attached
-- @param networkId number signifying the networkId of this entity
-- @param entities table to which entity data is serialized
--
-- NOTE: a Vector2int16 actually contains 2 values of the type int16, but these may be treated as uint16 (two's complement)
--
-- table entities:
--
--    { ..., Vector2int16[uint16 networkId, uint16 flags], Vector2int16[uint16 halfWord1, uint16 halfWord2], ...* }
--
--    *one additional Vector2int16 struct per non-zero componentId field word
--     (If this is a destruction message, zero additional Vector2int16s are created)
--
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0 _
--   0	 |   0   |   0   |   0   |   0       0       0       0       0       0       0       0       0       0   |   0       0  |
--       |       |       |       |                                                                               |              |
-- if set| if set| if set| if set|                                       n/a                                     |    cOffset   |
-- update| isRef |destroy|prefabE|                                                                               |              |
--------------------------------------------------------------------------------------------------------------------------------
--
--[ 0, 3 ] : field representing indices of non-zero values of _entityMap[instance][0]
--[ 4, 10] : 7-bit integer representing the total number of components on this entity
--           (unused if 14th bit is set)
--[11, 12] : N/A
--     13  : bit representing whether this is a destruction message
--     14  : bit representing whether entity is referenced in the system
--           (unused if 14th bit is set)
--     15  : bit representing whether this is an update message or a creation/destruction message
--           (always unset for messages generated by this function)
------------------------------------------------------------------------------------------------------------------------------
-- @param params table to which parameter values are serialized
-- table params:
--
--    { ..., value, value, value, ...* }
--
--    *one additional value for each parameter on this entity, if applicable
------------------------------------------------------------------------------------------------------------------------------
-- @param entitiesIndex number indicating current index of entities; initial value should be 1
-- @param paramsIndex number indicating current index of params; initial value should be 0
-- @param isDestruction boolean indicating whether this is a creation message or a destruction message
-- @param isReferenced boolean indicating whether this entity is referenced
-- @return number entitiesIndex
-- @return number paramsIndex
function Shared.SerializeEntity(instance, networkId, entities, params, entitiesIndex, paramsIndex, isDestruction, isReferenced, isPrefab)
	local entityStruct = entityMap[instance]
	local bitFields = entityStruct[0]
	local firstWord = bitFields[1]
	local secondWord = bitFields[2]
	local flags = 0
	local offset = 0
	local numDataStructs = 0
	local setBitPos = 0
	local componentId = 0
	local numComponents

	if isDestruction then
		flags = setBitAtPos(flags, 13)
		entities[entitiesIndex] = Vector2int16.new(networkId, flags)
		entitiesIndex = entitiesIndex + 1
		return entitiesIndex, paramsIndex
	end

	if firstWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(firstWord, 0, 16), bExtract(firstWord, 16, 16))

		for _ = 1, popCount(firstWord) do
			offset = findFirstSetPos(firstWord)
			componentId = offset + 1
			firstWord = unsetBitAtPos(firstWord, offset)

			for _, v in ipairs(componentMap[componentId][entityStruct[componentId]]) do
				paramsIndex = paramsIndex = 1
				params[paramsIndex] = v
			end

			if firstWord == 0 then
				break
			end
		end
	end

	if secondWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(secondWord, 0, 16), bExtract(secondWord, 16, 16))

		for _ = 1, popCount(secondWord) do
			offset = findFirstSetPos(secondWord)
			componentId = offset + 1
			secondWord = unsetBitAtPos(secondWord, offset)

			for _, v in ipairs(componentMap[componentId][entityStruct[componentId]]) do
				paramsIndex = paramsIndex = 1
				params[paramsIndex] = v
			end

			if secondWord == 0 then
				break
			end
		end
	end

	if isReferenced then
		flags = setBitAtPos(flags, 14)
	end

	entities[entitiesIndex - numDataStructs] = Vector2int16.new(networkId, flags)
	entitiesIndex = entitiesIndex + 1

	return entitiesIndex, paramsIndex
end

---Deserializes the next message in entities
-- @param entities table containing serial entity data
-- @param params table containing serial param data
-- @param entitiesIndex number indicating current index in entities
-- @param paramsIndex number indicating current index in params
-- @return number networkId
-- @return table componentIdsToParams
-- @return number entitiesIndex
-- @return number paramsIndex
-- @return boolean isDestruction
-- @return boolean isReferenced
-- @return boolean isUpdate
-- @return boolean doAdd
-- @return boolean doKill
function Shared.DeserializeNext(entities, params, entitiesIndex, paramsIndex)
	local networkIdDataObj = entities[entitiesIndex]
	local networkId = bOr(networkIdDataObj.X, 0) -- cast to unsigned
	local flags = networkIdDataObj.Y
	local numBitFields = 0
	local bitFieldOffsets = {}

	if checkFlag(flags, UPDATE) then
		return deserializeUpdate(entities, params, entitiesIndex, paramsIndex)
	else
		return deserializeEntity(entities, params, entitiesIndex, paramsIndex)
	end
end

function Shared.QueueUpdate(instance, msgType, componentId, paramId, players)
	local messages = Queued[instance]

	if not messages then
		messages = {}
		Queued[instance] = messages
	end

	local msg = messages[msgType]
	local params = msg[componentId]

	if not msg then
		msg = {}
		Queued[instance][msgType] = msg
	end

	local paramsField = params and (typeof(params) == "number" and params)

	msg[componentId] = paramsField and setBitAtPos(paramsField or 0, paramId - 1) or true
	msg[0] = players or nil
end

function Shared.Init(entityMap, componentMap)
	entityMap = entityMap
	componentMap = componentMap
end

return Shared


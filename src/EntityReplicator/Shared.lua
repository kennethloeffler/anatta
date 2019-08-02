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
local QueuedParams = {}
local bitSetLookup = {}
local entityMap
local componentMap

Shared.Queued = Queued
Shared.QueuedParams = QueuedParams

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

local function findFirstSetPos(field)
	return bitSetLookup[bAnd(field, -field)]
end

setBitAtPos = Shared.SetBitAtPos
unsetBitAtPos = Shared.UnsetBitAtPos

---Serializes a CLIENT_SERIALIZABLE network message
-- @param entities
-- 
-- table entities:
--     {
--       ... Vector2int16[uint16 halfWord1, halfWord2], ...,*
--       Vector2int16[uint16 paramField1, paramField2], ...**
--     }
-- 
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1	 |   0   |   0   |   0   |   0   |   1   |   0       0   |   0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |       |       |               |               |               |               |              |
-- if set|  n/a  |  n/a  |  n/a  |  n/a  | if set|      n/a      |      n/a      |      n/a      |      n/a      | clientSOffset|
-- update|       |       |       |       |clientS|               |               |               |               |              |
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
local function serializeClientSerializable(entities, params, entitiesIndex, paramsIndex, componentsMap, flags)
	local numDataStructs = 0
	local numComponents = 0
	local firstWord = 0
	local secondWord = 0
	local paramsField = 0
	local lastParamsField = 0
	local offset = 0
	local componentId = 0

	for componentId in pairs(componentsMap) do
		offset = math.floor(componentId * 0.01325) -- componentId / 32
		firstWord = offset == 0 and setBitAtPos(firstWord, componentId - 1)
		secondWord = offset == 1 and setBitAtPos(secondWord, componentId - 33)
		flags = setBitAtPos(flags, 2 - offset)
	end

	if firstWord ~= 0 then
		numDataStructs = numDataStructs + 1
		entitiesIndex = entitiesIndex + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(firstWord, 0, 16), bExtract(firstWord, 16, 16))

		for _ = 1, 32 do
			offset = findFirstSetPos(firstWord)
			numComponents = numComponents + 1
			paramsField = componentsMap[offset + 1]
			firstWord = unsetBitAtPos(firstWord, offset)

			if bAnd(numComponents, 1) == 0 then
				entitiesIndex = entitiesIndex + 1
				numDataStructs = numDataStructs + 1
				entities[entitiesIndex] = Vector2int16.new(lastParamField, paramsField)
			else
				lastParamField = paramsField
			end
		end

		if firstWord == 0 then
			if numComponents == 1 then
				entitiesIndex = entitiesIndex + 1
				numDataStructs = numDataStructs + 1
				entities[entitiesIndex] = Vector2int16.new(lastParamField, 0)
			end
			break
		end
	end

	if secondWord ~= 0 then
		numDataStructs = numDataStructs + 1
		entitiesIndex = entitiesIndex + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(secondWord, 0, 16), bExtract(secondWord, 16, 16))

		for _ = 1, 32 do
			offset = findFirstSetPos(secondWord)
			numComponents = numComponents + 1
			paramsField = componentsMap[offset + 1]
			secondWord = unsetBitAtPos(secondWord, offset)

			if bAnd(numComponents, 1) == 0 then
				entitiesIndex = entitiesIndex + 1
				numDataStructs = numDataStructs + 1
				entities[entitiesIndex] = Vector2int16.new(lastParamField, paramsField)
			else
				lastParamField = paramsField
			end
		end

		if secondWord == 0 then
			if numComponents == 1 then
				entitiesIndex = entitiesIndex + 1
				numDataStructs = numDataStructs + 1
				entities[entitiesIndex] = Vector2int16.new(lastParamField, 0)
			end
			break
		end
	end

	return entitiesIndex, paramsIndex, numDataStructs, flags
end

---Serializes a CLIENT_CREATABLE network message
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
--   1	 |   0   |   0   |   0   |   1   |   0   |   0       0   |   0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |       |       |               |               |               |               |              |
-- if set|  n/a  |  n/a  |  n/a  | if set|  n/a  |      n/a      |      n/a      |      n/a      | clientCOffset |      n/a     |
-- update|       |       |       |clientC|       |               |               |               |               |              |
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
local function serializeClientCreatable(entities, params, entitiesIndex, paramsIndex, componentsMap, flags)
	local numDataStructs = 0
	local firstWord = 0
	local secondWord = 0
	local offset = 0

	for componentId in pairs(componentsMap) do
		offset = math.floor(componentId * 0.01325) -- componentId / 32
		firstWord = offset == 0 and setBitAtPos(firstWord, componentId - 1)
		secondWord = offset == 1 and setBitAtPos(secondWord, componentId - 33)
		flags = setBitAtPos(flags, 3 - offset)
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

---Serializes a KILL_COMPONENT network message
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

		for _ = 1, 32 do
			componentOffset = findFirstSetPos(firstWord)
			firstWord = unsetBitAtPos(componentOffset)
			componentId = componentOffset + 1

			for _, v in ipairs(componentMap[componentId][entityMap[instance][componentId]]) do
				paramsIndex = paramsIndex + 1
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

		for _ = 1, 32 do
			componentOffset = findFirstSetPos(secondWord)
			firstWord = unsetBitAtPos(componentOffset)
			componentId = componentOffset + 1

			for _, v in ipairs(componentMap[componentId][entityMap[instance][componentId]]) do
				paramsIndex = paramsIndex + 1
				params[paramsIndex] = v
			end

			if firstWord == 0 then
				break
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

		for _ = 1, 32 do
			componentId = findFirstSetPos(firstWord) + 1
			numComponents = numComponents + 1
			paramsField = componentsMap[componentId]
			firstWord = unsetBitAtPos(firstWord, componentId - 1)

			for _ = 1, 16 do
				paramId = findFirstSetPos(paramsField) + 1
				paramsIndex = paramsIndex + 1
				params[paramsIndex] = componentMap[componentId][entityMap[instance]][paramId]
				paramsField = unsetBitAtPos(paramId - 1)

				if paramsField == 0 then
					break
				end
			end

			if bAnd(numComponents, 1) == 0 then
				entitiesIndex = entitiesIndex + 1
				numDataStructs = numDataStructs + 1
				entities[entitiesIndex] = Vector2int16.new(lastParamsField, componentsMap[componentId])
			else
				lastParamsField = componentsMap[componentId]
			end

			if firstWord == 0 then
				if numComponents == 1 then
					entitiesIndex = entitiesIndex + 1
					numDataStructs = numDataStructs + 1
					entities[entitiesIndex] = Vector2int16.new(lastParamsField, 0)
				end
				break
			end
		end
	end
  	
	if secondWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		entities[entitiesIndex] = Vector2int16.new(bExtract(secondWord, 0, 16), bExtract(secondWord, 16, 16))

		for _ = 1, 32 do
			componentId = findFirstSetPos(secondWord) + 33
			paramsField = componentsMap[componentId]
			secondWord = unsetBitAtPos(secondWord, componentId - 33)
			numComponents = numComponents + 1

			for _ = 1, 16 do
				paramId = findFirstSetPos(paramsField) + 1
				paramsIndex = paramsIndex + 1
				params[paramsIndex] = componentMap[componentId][entityMap[instance]][paramId]
				paramsField = unsetBitAtPos(paramId - 1)

				if paramsField == 0 then
					break
				end
			end


			if bAnd(numComponents, 1) == 0 then
				entitiesIndex = entitiesIndex + 1
				numDataStructs = numDataStructs + 1
				entities[entitiesIndex] = Vector2int16.new(lastParamsField, componentsMap[componentId])
			else
				lastParamsField = componentsMap[componentId]
			end	

			if secondWord == 0 then
				if numComponents == 1 then
					entitiesIndex = entitiesIndex + 1
					numDataStructs = numDataStructs + 1
					entities[entitiesIndex] = Vector2int16.new(lastParamsField, 0)
				end
				break
			end
		end
	end

	return entitiesIndex, paramsIndex, flags, numDataStructs
end

local function deserializeClientSerializable(networkId, entities, params, entitiesIndex, paramsIndex, flags)
	if SERVER then
		return nil, nil
	end

	local instance = instancesByNetworkId[networkId]
	local index = ""
	local firstWord = isFlagged(flags, 1)
	local offset = 0
	local numComponents = 0
	local componentId = 0
	local paramId = 0
	local paramOffset = 0
	local dataObj
	local secondWord = isFlagged(flags, 0)

	CollectionService:AddTag(instance, "__WSClientSerializable")

	if firstWord then
		entitiesIndex = entitiesindex + 1
		dataObj = entities[entitiesIndex]
		firstWord = bReplace(dataObj.X, dataObj.Y, 16, 16)
		
		for _ = 1, 32 do
			numComponents = numComponents + 1
			index = bAnd(numComponents, 1) == 0 and "Y" or "X"
			offset = findFirstSetPos(firstWord)
			firstWord = unsetBitAtPos(firstWord, offset)
			componentId = offset + 1
			
			for _ = 1, 16 do
				paramOffset = findFirstSetPos(
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
local function deserializeNextUpdate(entities, params, entitiesIndex, paramsIndex, player)
	local dataObj = entities[entitiesIndex]
	local networkId = dataObj.X
	local flags = dataObj.Y

	paramsIndex = paramsIndex + 1

	if isFlagged(flags, PARAMS_UPDATE) then
		entitiesIndex, paramsIndex = deserializeParamsUpdate(networkId, entities, params, entitiesIndex, paramsIndex, player)
	end

	if isFlagged(flags, ADD_COMPONENT) then
		entitiesIndex, paramsIndex = deserializeAddComponent(networkId, entities, params, entitiesIndex, paramsIndex, player)
	end

	if isFlagged(flags, KILL_COMPONENT) then
		entitiesIndex, paramsIndex = deserializeKillComponent(networkId, entities, params, entitiesIndex, paramsIndex, player)
	end

	if isFlagged(flags, CLIENT_CREATABLE) then
		entitiesIndex, paramsIndex = deserializeClientCreatable(entities, params, entitiesIndex, paramsIndex)
	end

	if isFlagged(flags, CLIENT_SERIALIZABLE) then
		entitiesIndex, paramsIndex = deserializeClientSerializable(entities, params, entitiesIndex, paramsIndex, flags)
	end

	return entitiesIndex, paramsIndex
end

---Serializes an entity update network message
-- @param instance Instance to which this entity is attached
-- @param networkId number the networkId for this entity
-- @param entities table to which entity data is written
-- 
-- table entities:
--     { Vector2int16[uint16 networkId, uint16 flags], 
--       Vector2int16[uint16 halfWord1, halfWord2], ...,*
--       Vector2int16[uint16 paramField1, paramField2], ...**
--     }
-- 
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1	 |   0   |   0   |   0   |   0   |   0   |   0       0   |   0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |       |       |               |               |               |               |              |
-- if set| if set| if set| if set| if set| if set|  paramsOffset |   addOffset   |   killOffset  | clientCOffset | clientSOffset|
-- update| params|  add  |  kill |clientC|clientS|               |               |               |               |              |
--------------------------------------------------------------------------------------------------------------------------------
--
-- @param params table to which parameter values are written
-- @param entitiesIndex number indicating the current index of entities
-- @param paramsIndex number indicating the current index of params
-- @param componentsMap table mapping component ids to either message types or lists of parameter ids
-- @return number entitiesIndex
-- @return number paramsIndex
function Shared.SerializeNextUpdate(instance, networkId, entities, params, entitiesIndex, paramsIndex, msgMap)
	local flags = 0
	local numDataStructs = 0
	local totalNumDataStructs = 0

	for msg, map in pairs(msgMap) do
		for _ = 1, 5 do
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
			elseif msg == CLIENT_CREATABLE then
				entitiesIndex, paramsIndex, flags, numDataStructs = serializeClientCreatable(
					entities, params,
					entitiesIndex, paramsIndex,
					map, flags
				)
			elseif msg == CLIENT_SERIALIZABLE then
				entitiesIndex, paramsIndex, flags, numDataStructs = serializeClientSerializable(
					entities, params,
					entitiesIndex, paramsIndex,
					map, flags
				)
			end

			totalNumDataStructs = totalNumDataStructs + numDataStructs
			msg = unsetBitAtPos(msgField, msg)

			if msg == 0 then
				break
			end
		end
	end

	entities[entitiesIndex - totalNumDataStructs] = Vector2int16.new(networkId, flags)
	entitesIndex = entitiesIndex + 1

	return entitiesIndex, paramsIndex
end

---Serializes an entity lifetime network message
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
function Shared.SerializeNext(instance, networkId, entities, params, entitiesIndex, paramsIndex, isDestruction, isReferenced, isPrefab)
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
		
		for _ = 1, 32 do
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
		
		for _ = 1, 32 do
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

function Shared.Queue(instance, msgType, componentId, arg)
	Queued[instance][msgType][componentId] = arg or true
end

function Shared.OnReference(instance)
	local t = {}
	t[UPDATE_PARAMS] = {}
	t[ADD_COMPONENT] = {}
	t[KILL_COMPONENT] = {}
	t[CLIENT_CREATABLE] = {}
	t[CLIENT_SERIALIZABLE] = {}
	Queued[instance] = t
end

function Shared.OnDereference(instance)
	Queued[instance] = nil
end
		
function Shared.Init(entityMap, componentMap)
	entityMap = entityMap
	componentMap = componentMap

	for i = 0, 31 do
		bitSetLookup[blShift(1, i)] = i
	end
end

return Shared


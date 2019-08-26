---Shared.lua
-- @module shared

-- Because the usage of Vector2int16 in this module may be confusing, a summary of why this data type was chosen is given below:

-- The bit32 functions truncate their arguments (signed 64 bit floats) to unsigned 32 bit integers. However, these functions
-- still return a normal Lua number (a signed 64 bit float). What this means practically is that *half* of the data will be
-- "junk" and waste valuable bandwidth when sent across the network. Because one of the design goals of EntityReplicator is
-- to minimize the amount of data sent among peers, this is an obvious non-starter.

-- Nevertheless, there does exist a way to efficently pack integers to send across the network. A Vector2int16 contains two
-- signed 16 bit integers: one in its 'X' field, and one in its 'Y' field. It is thus possible to split an unsigned 32-bit
-- integer into two 16-bit fields, which are placed in the Vector2int16, then send the Vector2int16 across the network where
-- it is deserialized by the receiving system.

-- If any one of these two 16-bit fields represents an integer that is greater than (2^15) - 1, it  will result in the same
-- unsigned value when it is used again as an argument in a bit32 function. This is because the signed 16-bit integers dealt with
-- here are in two's complement form, so inputting a positive integer n outside of the range they can represent will result in a
-- negative number -(~(n - 1)) whose binary representation is identical to that of the original number, as long as the original
-- number does not exceed (2^16) - 1.

local ComponentDesc = require(script.Parent.Parent.ComponentDesc)
local Constants = require(script.Parent.Constants)

local UPDATE = Constants.UPDATE
local PARAMS_UPDATE = Constants.PARAMS_UPDATE
local ADD_COMPONENT = Constants.ADD_COMPONENT
local KILL_COMPONENT = Constants.KILL_COMPONENT
local IS_REFERENCED = Constants.IS_REFERENCED
local DESTRUCTION = Constants.DESTRUCTION
local PREFAB_ENTITY = Constants.PREFAB_ENTITY
local IS_SERVER = Constants.IS_SERVER

local Shared = {}

local Queued = {}
local InstancesByNetworkId = {}
local NetworkIdsByInstance = {}
local GlobalRefs = {}
local PlayerRefs = {}
local NumParams = ComponentDesc.NumParamsByComponentId

local EntityMap
local ComponentMap
local AddComponent
local KillComponent
local ClientCreatable
local ClientSerializable

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

---Returns TRUE if the bit at position pos is set, FALSE otherwise
-- n is truncated to a 32-bit integer by bit32
-- @param n number
-- @param pos number

local function isbitset(n, pos)
	return bit32.band(bit32.rshift(n, pos), 1) ~= 0
end

---Sets the bit at position pos in the binary representation of n
-- n is truncated to a 32-bit integer by bit32
-- @param n number
-- @param pos number
-- @return n

local function setbit(n, pos)
	return bit32.bor(n, bit32.lshift(1, pos))
end

---Unsets the bit at position pos in the binary representation of n
-- n is truncated to an unsigned 32-bit integer by bit32
-- @param n number
-- @return n

local function unsetbit(n, pos)
	return bit32.band(n, bit32.bnot(bit32.lshift(1, pos)))
end

---Counts the number of set bits in the binary representation of n
-- n is truncated to an unsigned 32-bit integer by bit32
-- in-depth explanations of this function can be found at:

--    https://web.archive.org/web/20060111231946/http://www.amd.com/us-en/assets/content_type/white_papers_and_tech_docs/25112.PDF
--    8.6, "Efficient Implementation of Population-Count Function in 32-Bit Mode"

--    https://doc.lagout.org/security/Hackers%20Delight.pdf
--    5-1, "Counting 1-Bits"
-- @param n number
-- @return PopCount

local function popcnt(n)
	-- add each two bits, store result in respective field
	n = n - bit32.band(bit32.rshift(n, 1), 0x55555555)
	-- add each four bits
	n = bit32.band(n, 0x33333333) + bit32.band(bit32.rshift(n, 2), 0x33333333)
	-- add each eight bits, sixteen bits; final value is last eight bits
	return bit32.rshift(bit32.band(n + bit32.rshift(n, 4), 0x0F0F0F0F) * 0x01010101, 24)
end

---Finds the position of the first set bit (starting from LSB) in the binary representation of n
-- n is truncated to an unsigned 32-bit integer by bit32
-- @param n number
-- @param FirstSet

local function ffs(n)
	return popcnt(bit32.band(bit32.bnot(n), n - 1))
end

local function invalidDataObj(dataObj)
	if not typeof(dataObj) == "Vector2int16" then
		return true
	end
end

local function hasPermission(player, networkId, componentId, paramId)
	local componentOffset = math.floor(componentId * 0.03125)
	local bitOffset = componentOffset - 1 - (componentOffset * 32)
	local playerArg
	local componentArg
	local paramArg

	-- checking if player is allowed to create this component
	if componentId and not paramId then
		playerArg = PlayerCreatable[networkId][1]
		componentArg = PlayerCreatable[networkId][componentOffset + 2]

		if not ((playerArg == ALL_CLIENTS or playerArg[player] or playerArg == player) and isbitset(componentArg, bitOffset)) then
			return
		else
			return true
		end
	-- checking if player is allowed to serialize to this parameter
	elseif paramId and componentId then
		playerArg = PlayerSerializable[networkId][1]
		paramArg = PlayerSerializable[networkId][componentId + 1]

		if not (paramsArg and (playerArg == ALL_CLIENTS or playerArg[player] or playerArg == player) and isbitset(paramArg, paramId - 1)) then
			return
		else
			return true
		end
	end
end

---Gets the id string corresponding to a positive integer num
-- @param num number
-- @return IdString

function Shared.GetIdStringFromNum(num)
	__IdLen = math.ceil(num * .00390625) -- num / 256
	__IdNum = num
	return string.rep("_", __IdLen):gsub(".", calcIdString())
end

---Gets the number corresponding to an id string str
-- @param str string
-- @return IdNum

function Shared.GetIdNumFromString(str)
	local id = 1
	for c in str:gmatch(".") do
		id = id + string.byte(c)
	end
	return id
end

--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1	 |   0   |   0   |   1   |   0       0       0       0       0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |                                               |               |               |              |
-- if set|  n/a  |  n/a  | if set|                    (unused)                   |      n/a      |      n/a      |  killOffset  |
-- update|       |       |  kill |                                               |               |               |              |
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
		firstWord = offset == 0 and setbit(firstWord, componentId - 1)
		secondWord = offset == 1 and setbit(secondWord, componentId - 33)
		flags = setbit(flags, offset)
	end

	if firstWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bit32.extract(firstWord, 0, 16), bit32.extract(firstWord, 16, 16))
	end

	if secondWord ~= 0 then
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bit32.extract(secondWord, 0, 16), bit32.extract(secondWord, 16, 16))
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
--   1	 |   0   |   1   |   0   |   0       0       0       0       0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |                                               |               |               |              |
-- if set|  n/a  | if set|  n/a  |                    (unused)                   |      n/a      |   addOffset   |      n/a     |
-- update|       |  add  |       |                                               |               |               |              |
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
	local entityStruct = EntityMap[instance]
	local numDataStructs = 0
	local componentOffset = 0
	local componentId = 0
	local offset = 0

	for fieldOffset, field in ipairs(entityStruct[0]) do
		if field ~= 0 then
			entitiesIndex = entitiesIndex + 1
			numDataStructs = numDataStructs + 1
			entities[entitiesIndex] = Vector2int16.new(bit32.extract(field, 0, 16), bit32.extract(field, 16, 16))

			for _ = 1, popcnt(field) do
				componentOffset = ffs(field)
				field = unsetbit(componentOffset)
				componentId = componentOffset + 1 + (32 * (fieldOffset - 1))
				offset = math.floor(componentId * 0.01325)
				flags = setbit(flags, 2 + offset)

				for _, v in ipairs(componentMap[componentId][entityStruct[componentId]]) do
					paramsIndex = paramsIndex + 1
					params[paramsIndex] = v
				end
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
--   1	 |   1   |   0   |   0   |   0       0       0       0       0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |                                               |               |               |              |
-- if set| if set|  n/a  |  n/a  |                    (unused)                   |  paramsOffset |      n/a      |      n/a     |
-- update| params|       |       |                                               |               |               |              |
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
	local entityStruct = EntityMap[instance]
	local offset = 0
	local numDataStructs = 0
	local numComponents = 0
	local paramsField = 0
	local lastParamsField = 0
	local paramId = 0
	local componentId

	for fieldOffset, field in ipairs(entityStruct[0]) do
		if field ~= 0 then
			entitiesIndex = entitiesIndex + 1
			numDataStructs = numDataStructs + 1
			entities[entitiesIndex] = Vector2int16.new(bit32.extract(field, 0, 16), bit32.extract(field, 16, 16))

			for _ = 1, popcnt(firstWord) do
				componentId = ffs(firstWord) + 1 + (32 * (fieldOffset - 1))
				offset = math.floor(componentId * 0.03125)
				flags = setbit(flags, 4 + offset)
				numComponents = numComponents + 1
				paramsField = componentsMap[componentId]
				firstWord = unsetbit(firstWord, componentId - 1)

				for _ = 1, popcnt(paramsField) do
					paramId = ffs(paramsField) + 1
					paramsIndex = paramsIndex + 1
					params[paramsIndex] = componentMap[componentId][entityStruct[componentId]][paramId]
					paramsField = unsetbit(paramId - 1)
				end

				if bit32.band(numComponents, 1) == 0 then
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
	end

	return entitiesIndex, paramsIndex, flags, numDataStructs
end

local function deserializeParamsUpdate(networkId, entities, params, entitiesIndex, paramsIndex, flags, player)
	local instance = InstancesByNetworkId[networkId]
	local fieldOffset = bit32.extract(flags, 4, 2)
	local offsetFactor = 0
	local field = 0
	local paramsField = 0
	local componentId = 0
	local pos = 0
	local paramPos = 0
	local even = false
	local dataObj

	for _ = 1, popcnt(fieldOffset) do
		entitiesIndex = enititiesIndex + 1
		dataObj = entities[entitiesIndex]
		offsetFactor = ffs(fieldOffset)
		fieldOffset = unsetbit(fieldOffset, offsetFactor)

		if player then
			if invalidDataObj(dataObj) then
				return nil
			end
		end

		field = bit32.replace(dataObj.X, dataObj.Y, 16, 16)

		for i = 1, popcnt(field) do
			pos = ffs(field)
			even = bit32.band(i, 0) == 0
			componentId = pos + (32 * offsetFactor) + 1
			entitiesIndex = entitiesIndex + (even and 1 or 0)
			dataObj = entities[entitiesIndex]

			if player and invalidDataObj(dataObj)
				return nil
			end

			paramsField = even and dataObj.X or dataObj.Y

			for _ = 1, popcnt(paramsField) do
				paramId = ffs(paramsField) + 1

				if player and not hasPermission(player, networkId, componentId, paramId) then
					return nil
				end

				componentMap[componentId][EntityMap[instance]][paramId] = params[paramsIndex]
				paramsIndex = paramsIndex + 1
				paramsField = unsetbit(paramsField, paramId - 1)
			end

			field = unsetbit(field, pos)
		end
	end

	return entitiesIndex, paramsIndex
end

local function deserializeAddComponent(networkId, entities, params, entitiesIndex, paramsIndex, flags, player)
	local instance = InstancesByNetworkId[networkId]
	local componentId = 0
	local fieldOffset = bit32.extract(flags, 2, 2)
	-- don't want to rehash while populating this
	local componentStruct = {
		true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
		_componentId = true, Instance = true
	}
	local pos = 0
	local offsetFactor = 0
	local dataObj
	local paramValue

	for _ = 1, popcnt(fieldOffset) do
		entitiesIndex = entitiesIndex + 1
		dataObj = entities[entitiesIndex]

		if player and invalidDataObj(dataObj) then
			return
		end

		field = bit32.replace(dataObj.X, dataObj.Y, 16, 16)
		offsetFactor = ffs(fieldOffset)
		fieldOffset = unsetbit(fieldOffset, offsetFactor)

		for _ = 1, popcnt(field) do
			pos = ffs(field)
			componentId = pos + (32 * offsetFactor) + 1
			field = unsetbit(field, pos)

			if player and not hasPermission(player, networkId, componentId) then
					return nil
			end

			for paramId = 1, NumParams[componentId] do
				paramsIndex = paramsIndex + 1
				paramValue = params[paramsIndex]

				if player and not typeof(paramValue) == typeof(GetParamDefault(componentId, paramId)) then
					return nil
				end

				componentStruct[paramId] = params[paramsIndex]
			end

			AddComponent(instance, componentId, componentStruct)
		end
	end
end

function deserializeKillComponent(networkId, entities, params, entitiesIndex, flags)
	local instance = InstancesByNetworkId[networkId]
	local componentId = 0
	local fieldOffset = bit32.extract(flags, 0, 2)
	local pos = 0
	local offsetFactor = 0
	local dataObj

	for _ = 1, popcnt(fieldOffset) do
		entitiesIndex = entitiesIndex + 1
		dataObj = entities[entitiesIndex]
		field = bit32.replace(dataObj.X, dataObj.Y, 16, 16)
		offsetFactor = ffs(fieldOffset)
		fieldOffset = unsetbit(fieldOffset, offsetFactor)

		for _ = 1, popcnt(field) do
			pos = ffs(field)
			componentId = pos + (32 * offsetFactor) + 1
			field = unsetbit(field, pos)
			KillComponent(instance, componentId)
		end
	end

	return entitiesIndex
end

local function deserializeEntity(entities, params, entitiesIndex, paramsIndex, instance)
	local dataObj = entities[entitiesIndex]
	local flags = dataObj.Y
	local field = 0
	local fieldOffset = bit32.extract(flags, 0, 2)
	local offsetFactor = 0

	for _ = 1, popcnt(fieldOffset) do
		entitiesIndex = entitiesIndex + 1
		dataObj = entities[entitiesIndex]
		field = bit32.replace(dataObj.X, dataObj.Y, 16, 16)
		offsetFactor = ffs(fieldOffset)
		fieldOffset = unsetbit(fieldOffsets, offsetFactor)

		for _ = 1, popcnt(field) do
			-- dont want to rehash when filling this
			local componentStruct = {
				true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
				_componentId = true, Instance = true
			}

			pos = ffs(field)
			field = unsetbit(field, pos)
			componentId = pos + (32 * offsetFactor) + 1

			for paramId = 1, NumParams[componentId] do
				paramsIndex = paramsIndex + 1
				componentStruct[paramId] = params[paramsIndex]
			end

			AddComponent(instance, componentId, componentStruct)
		end
	end

	return entitiesIndex, paramsIndex
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
local function deserializeUpdate(entities, params, entitiesIndex, paramsIndex, playerArg)
	local dataObj = entities[entitiesIndex]
	local networkId = dataObj.X
	local flags = dataObj.Y

	if isbitset(flags, PARAMS_UPDATE) then
		entitiesIndex, paramsIndex = deserializeParamsUpdate(
			networkId, entities, params,
			entitiesIndex, paramsIndex,
			flags, playerArg
		)
	end

	if isbitset(flags, ADD_COMPONENT) then
		entitiesIndex, paramsIndex = deserializeAddComponent(
			networkId, entities, params,
			entitiesIndex, paramsIndex,
			flags, playerArg
		)
	end

	if isbitset(flags, KILL_COMPONENT) then
		entitiesIndex = deserializeKillComponent(
			networkId, entities, params,
			entitiesIndex, flags, playerArg
		)
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
--       Vector2int16[uint16 halfWord1, uint16 halfWord2], ...,*
--       Vector2int16[uint16 paramField1, uint16 paramField2], ...**
--     }
--
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1	 |   0   |   0   |   0   |   0       0       0       0       0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |                                               |               |               |              |
-- if set| if set| if set| if set|                    (unused)                   |  paramsOffset |   addOffset   |  killOffset  |
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

	-- read message fields to figure out which msgTypes we're sending for each component type
	for msg, map in pairs(msgMap) do
		for _ = 1, popcnt(msg) do
			msg = ffs(msg)
			flags = setbit(flags, msg)

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
			msg = unsetbit(msgField, msg)
		end

		MsgMap[msg] = nil
	end

	-- create header and increment entity table index
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
--[ 0, 1 ] : field representing non-zero indices of EntityMap[instance][0]
--     D  : bit representing whether this is a destruction message
--     E  : bit representing whether entity is referenced in the system
--           (unused if bit D is set)
--     F  : bit representing whether this is an update message or a creation/destruction message
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
function Shared.SerializeEntity(instance, networkId, entities, params, entitiesIndex, paramsIndex, isDestruction, isReferenced)
	local entityStruct = EntityMap[instance]
	local flags = 0
	local offset = 0
	local numDataStructs = 0
	local setBitPos = 0
	local componentId = 0
	local numComponents
	local default

	if isDestruction then
		flags = setbit(flags, DESTRUCTION)
		entities[entitiesIndex] = Vector2int16.new(networkId, flags)
		entitiesIndex = entitiesIndex + 1
		return entitiesIndex, paramsIndex
	end

	for fieldOffset, field in ipairs(entityStruct[0]) do
		if field ~= 0 then
			entitiesIndex = entitiesIndex + 1
			numDataStructs = numDataStructs + 1
			entities[entitiesIndex] = Vector2int16.new(bit32.extract(field, 0, 16), bit32.extract(field, 16, 16))

			for _ = 1, popcnt(field) do
				offset = ffs(field)
				componentId = offset + 1 + (32 * (fieldOffset - 1))
				default = Defaults[componentId]
				field = unsetbit(field, offset)

				for paramId, v in ipairs(componentMap[componentId][entityStruct[componentId]]) do
					if default[paramId] then
						paramsIndex = paramsIndex = 1
						params[paramsIndex] = v
					end
				end
			end
		end
	end

	if isReferenced then
		flags = setbit(flags, IS_REFERENCED)
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
function Shared.DeserializeNext(entities, params, entitiesIndex, paramsIndex, playerOrEntityRef)
	local dataObj = entities[entitiesIndex]

	if invalidDataObj(dataObj) then
		return
	end

	if isbitset(dataObj.Y, UPDATE) then
		return deserializeUpdate(entities, params, entitiesIndex, paramsIndex, playerOrEntityRef)
	else
		return deserializeEntity(entities, params, entitiesIndex, paramsIndex, playerOrEntityRef)
	end
end

function Shared.QueueUpdate(instance, msgType, componentId, paramId)
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

	msg[componentId] = paramsField and setbit(paramsField or 0, paramId - 1) or true
end

function Shared.OnNewReference(instance, networkId)
	InstancesByNetworkId[networkId] = instance
	NetworkIdsByInstance[instance] = networkId
end

function Shared.OnDereference(instance, networkId)
	InstancesByNetworkId[networkId] = instance
	NetworkIdsNyInstance[instance] = networkId
end

function Shared.Init(entityManager, entityMap, componentMap, clientCreatable, clientSerializable)
	EntityMap = entityMap
	ComponentMap = componentMap
	AddComponent = entityManager.AddComponent
	KillComponent = entityManager.KillComponent
	ClientCreatable = clientCreatable
	ClientSerializable = clientSerializable
end

return Shared


---Shared.lua

-- Because the usage of Vector2int16 in this module may be confusing, a summary of why this data type was chosen is given below:
--
-- The bit32 functions truncate their arguments (signed 64 bit floats) to unsigned 32 bit integers. However, these functions
-- still return a normal Lua number (a signed 64 bit float). What this means practically is that *half* of the data will be
-- "junk" and waste valuable bandwidth when sent across the network. Because one of the design goals of EntityReplicator is
-- to minimize the amount of data sent among peers, this is an obvious non-starter.
--
-- Nevertheless, there does exist a way to efficiently pack integers to send across the network. A Vector2int16 contains two
-- signed 16 bit integers: one in its 'X' field, and one in its 'Y' field. It is thus possible to split an unsigned 32-bit
-- integer into two 16-bit fields, which are placed in the Vector2int16, then send the Vector2int16 across the network where
-- it is deserialized by the receiving system.
--
-- If any one of these two 16-bit fields represents an integer that is greater than (2^15) - 1, it  will result in the same
-- unsigned value when it is used again as an argument in a bit32 function. This is because the signed 16-bit integers dealt with
-- here are in two's complement form, so inputting a positive integer n outside of the range they can represent will result in a
-- number -(~(n - 1)) with a binary representation that is identical to that of the original number, as long as the original
-- number does not exceed (2^16) - 1.

local CollectionService = game:GetService("CollectionService")

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
local NumParams = ComponentDesc.NumParamsByComponentId
local Server
local BlacklistedComponents
local ClientSerializable
local ClientCreatable

local EntityMap
local ComponentMap
local AddComponent
local KillComponent
local ClientCreatable
local ClientSerializable

Shared.Queued = Queued
Shared.InstancesByNetworkId = InstancesByNetworkId
Shared.NetworkIdsByInstance  NetworkIdsByInstance

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
	return not typeof(dataObj) == "Vector2int16"
end

local function hasPermission(player, instance, componentId, paramId)
	local componentOffset = math.floor(componentId * 0.03125)
	local bitOffset = componentOffset - 1 - (componentOffset * 32)
	local playerArg
	local componentField
	local paramField

	-- checking if player is allowed to create this component on this entity
	if componentId and not paramId then
		playerArg = PlayerCreatable[instance][1]
		componentField = PlayerCreatable[instance][componentOffset + 2]

		if not ((playerArg == ALL_CLIENTS or playerArg[player] or playerArg == player) and isbitset(componentField, bitOffset)) then
			return
		else
			return true
		end
	-- checking if player is allowed to serialize to this parameter on this entity
	elseif paramId and componentId then
		playerArg = PlayerSerializable[instance][1]
		paramField = PlayerSerializable[instance][componentId + 1]

		if not (paramField and (playerArg == ALL_CLIENTS or playerArg[player] or playerArg == player) and isbitset(paramField, paramId - 1)) then
			return
		else
			return true
		end
	end
end

Shared.setbit = setbit

---Converts a networkId to a string
-- @param networkId number
-- @return IdString

function Shared.GetStringFromNetworkId(networkId)
	return string.char(bit32.extract(networkId, 0, 8), bit32.extract(networkId, 8, 8))
end

local GetStringFromNetworkId = Shared.GetStringFromNetworkId

---Serializes a KILL_COMPONENT network message
-- @param entities
-- table entities:
--
--      { Vector2int16(halfWord1, halfWord2), ... }
--
--------------------------------------------------------------------------------------------------------------------------------
-- @param entitiesIndex
-- @param componentsMap
-- @param flags
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1   |   0   |   0   |   1   |   0       0       0       0       0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |                                               |               |               |              |
-- if set|  n/a  |  n/a  | if set|                    (unused)                   |      n/a      |      n/a      |  killOffset  |
-- update|       |       |  kill |                                               |               |               |              |
--------------------------------------------------------------------------------------------------------------------------------
--
-- @return entitiesIndex
-- @return flags
-- @return numDataStructs

local function serializeKillComponent(entities, entitiesIndex, componentsMap, flags)
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

	return entitiesIndex, flags, numDataStructs
end

---Serializes an ADD_COMPONENT network message
-- @param instance
-- @param entities
-- table entities:
--
--      { ..., Vector2int16(halfWord1, halfWord2), ... }
--
--------------------------------------------------------------------------------------------------------------------------------
-- @param instance
-- @param entities
-- @param params
-- table params:
--
--      { ..., value, value, value, ... }
--
--------------------------------------------------------------------------------------------------------------------------------
-- @param entitiesIndex
-- @param paramsIndex
-- @param componentsMap
-- @param flags
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1   |   0   |   1   |   0   |   0       0       0       0       0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |                                               |               |               |              |
-- if set|  n/a  | if set|  n/a  |                    (unused)                   |      n/a      |   addOffset   |      n/a     |
-- update|       |  add  |       |                                               |               |               |              |
--------------------------------------------------------------------------------------------------------------------------------
--
-- @return entitiesIndex
-- @return paramsIndex
-- @return flags
-- @return numDataStructs

local function serializeAddComponent(instance, entities, params, entitiesIndex, paramsIndex, componentsMap, flags)
	local entityStruct = EntityMap[instance]
	local firstWord = 0
	local secondWord = 0
	local numDataStructs = 0
	local componentOffset = 0
	local componentId = 0
	local offset = 0
	local both

	for componentId in pairs(componentsMap) do
		firstWord = componentId <= 32 and setbit(firstWord, componentId - 1) or firstWord
		secondWord = componentId > 32 and setbit(secondWord, componentId - 33) or secondWord
	end

	-- yeah im BOTH
	both = firstWord ~= 0 and secondWord ~= 0

	for fieldOffset = 1, both and 2 or 1 do
		fieldOffset = both and fieldOffset or (secondWord ~= 0 and 2 or 1)
		field = fieldOffset == 1 and firstWord or secondWord

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
				params[paramsIndex] = v
				paramsIndex = paramsIndex + 1
			end
		end
	end

	return entitiesIndex, paramsIndex, flags, numDataStructs
end

---Serializes a PARAM_UPDATE network message
-- @param instance
-- @param entities
-- table entities:
--
--      { ..., Vector2int16(halfWord1, halfWord2), ...
--        Vector2int16(paramsField1, paramsField2), ... }
--
--------------------------------------------------------------------------------------------------------------------------------
-- @param params
-- table params:
--
--      { ..., value, value, value, ... }
--
--------------------------------------------------------------------------------------------------------------------------------
-- @param entitiesIndex
-- @param paramsIndex
-- @param componentsMap
-- @param flags
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0__
--   1   |   1   |   0   |   0   |   0       0       0       0       0       0   |   0       0   |   0       0   |   0       0  |
--       |       |       |       |                                               |               |               |              |
-- if set| if set|  n/a  |  n/a  |                    (unused)                   |  paramsOffset |      n/a      |      n/a     |
-- update| params|       |       |                                               |               |               |              |
--------------------------------------------------------------------------------------------------------------------------------

-- @return entitiesIndex
-- @return paramsIndex
-- @return flags
-- @return numDataStructs

local function serializeParameterUpdate(instance, entities, params, entitiesIndex, paramsIndex, componentsMap, flags)
	local firstWord = 0
	local secondWord = 0
	local offset = 0
	local numDataStructs = 0
	local numComponents = 0
	local paramsField = 0
	local lastParamsField = 0
	local paramId = 0
	local both
	local componentId

	for componentId, cParamField in pairs(componentsMap) do
		firstWord = componentId <= 32 and setbit(firstWord, componentId - 1) or firstWord
		secondWord = componentId > 32 and setbit(secondWord, componentId - 33) or secondWord
	end

	both = firstWord ~= 0 and secondWord ~= 0

	for fieldOffset = 1, (both and 2 or 1) do
		fieldOffset = both and fieldOffset or (secondWord ~= 0 and 2 or 1)
		field = fieldOffset == 1 and firstWord or secondWord

		numComponents = 0
		entitiesIndex = entitiesIndex + 1
		numDataStructs = numDataStructs + 1
		entities[entitiesIndex] = Vector2int16.new(bit32.extract(field, 0, 16), bit32.extract(field, 16, 16))

		for _ = 1, popcnt(field) do
			componentId = ffs(field) + 1 + (32 * (fieldOffset - 1))
			offset = math.floor(componentId * 0.03125)
			flags = setbit(flags, 4 + offset)
			numComponents = numComponents + 1
			paramsField = componentsMap[componentId]
			field = unsetbit(field, componentId - 1)

			for _ = 1, popcnt(paramsField) do
				paramId = ffs(paramsField) + 1
				params[paramsIndex] = ComponentMap[componentId][entityStruct[componentId]][paramId]
				paramsIndex = paramsIndex + 1
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

	return entitiesIndex, paramsIndex, flags, numDataStructs
end

local function deserializeParamsUpdate(networkId, entities, params, entitiesIndex, paramsIndex, flags, player, instance)
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
		entiites[entitiesIndex] = nil
		offsetFactor = ffs(fieldOffset)
		fieldOffset = unsetbit(fieldOffset, offsetFactor)

		if player and invalidDataObj(dataObj) then
			return
		end

		field = bit32.replace(dataObj.X, dataObj.Y, 16, 16)

		for i = 1, popcnt(field) do
			pos = ffs(field)
			even = bit32.band(i, 0) == 0
			componentId = pos + (32 * offsetFactor) + 1
			entitiesIndex = entitiesIndex + (even and 1 or 0)
			dataObj = entities[entitiesIndex]
			paramsField = even and dataObj.X or dataObj.Y
			entities[entitiesIndex] = nil

			if player and invalidDataObj(dataObj)
				return
			end

			for _ = 1, popcnt(paramsField) do
				paramId = ffs(paramsField) + 1

				if player and not hasPermission(player, instance, componentId, paramId) then
					return
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

local function deserializeAddComponent(networkId, entities, params, entitiesIndex, paramsIndex, flags, player, instance)
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
		entities[entitiesIndex] = nil
		offsetFactor = ffs(fieldOffset)
		fieldOffset = unsetbit(fieldOffset, offsetFactor)

		for _ = 1, popcnt(field) do
			pos = ffs(field)
			componentId = pos + (32 * offsetFactor) + 1
			field = unsetbit(field, pos)

			if player and not hasPermission(player, instance, componentId) then
				return
			end

			for paramId = 1, NumParams[componentId] do
				paramsIndex = paramsIndex + 1
				paramValue = params[paramsIndex]

				if player and not typeof(paramValue) == typeof(GetParamDefault(componentId, paramId)) then
					return
				end

				componentStruct[paramId] = params[paramsIndex]
			end

			AddComponent(instance, componentId, componentStruct)
		end
	end
end

function deserializeKillComponent(networkId, entities, params, entitiesIndex, flags, instance)
	local instance = InstancesByNetworkId[networkId]
	local componentId = 0
	local fieldOffset = bit32.extract(flags, 0, 2)
	local pos = 0
	local offsetFactor = 0
	local dataObj

	if IS_SERVER then
		return
	end

	for _ = 1, popcnt(fieldOffset) do
		entitiesIndex = entitiesIndex + 1
		dataObj = entities[entitiesIndex]
		field = bit32.replace(dataObj.X, dataObj.Y, 16, 16)
		entities[entitiesIndex] = nil
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

local function deserializeEntity(networkId, flags, entities, params, entitiesIndex, paramsIndex, arg)
	local dataObj
	local field = 0
	local isDestruction = isbitset(flags, IS_DESTRUCTION)
	local isReferenced = isbitset(flags, IS_REFERENCED)
	local isPrefab = isbitset(flags, IS_PREFAB)
	local isUnique = isbitset(flags, IS_UNIQUE)
	local idStr = GetStringFromNetworkId(networkId)
	local instance = isPrefab and (isReferenced and arg._r[idStr] or arg._s[idStr]) or (isUnique and arg or CollectionService:GetTagged(idStr)[1])
	local fieldOffset = bit32.extract(flags, 0, 2)
	local offsetFactor = 0

	if isDestruction then
		entitiesIndex = entitiesIndex + 1
		InstancesByNetworkId[networkId] = nil
		NetworkIdsByInstance[instance] = nil

		CollectionService:RemoveTag(instance, idStr)
		KillEntity(instance)

		return entitiesIndex, paramsIndex
	end

	for _ = 1, popcnt(fieldOffset) do
		entitiesIndex = entitiesIndex + 1
		dataObj = entities[entitiesIndex]
		field = bit32.replace(dataObj.X, dataObj.Y, 16, 16)
		entities[entitiesIndex] = nil
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

	NetworkIdsByInstance[instance] = networkId
	InstancesByNetworkId[networkId] = instance

	return entitiesIndex, paramsIndex
end

---Deserializes the update message in entities at position entitiesIndex
-- @param networkId
-- @param flags
-- @param entities table
-- @param params table
-- @param entitiesIndex number
-- @param paramsIndex number
-- @param instance
-- @param player
-- @return number entitiesIndex
-- @return number paramsIndex

local function deserializeUpdate(networkId, flags, entities, params, entitiesIndex, paramsIndex, instance, player)
	if isbitset(flags, PARAMS_UPDATE) then
		entitiesIndex, paramsIndex = deserializeParamsUpdate(
			networkId, entities, params,
			entitiesIndex, paramsIndex,
			flags, player, instance
		)
	end

	if isbitset(flags, ADD_COMPONENT) then
		entitiesIndex, paramsIndex = deserializeAddComponent(
			networkId, entities, params,
			entitiesIndex, paramsIndex,
			flags, player, instance
		)
	end

	if isbitset(flags, KILL_COMPONENT) then
		entitiesIndex = deserializeKillComponent(
			networkId, entities, params,
			entitiesIndex, flags, player, instance
		)
	end

	return entitiesIndex, paramsIndex
end

---Serializes an entity update network message
-- @param instance Instance to which this entity is attached
-- @param networkId number the networkId for this entity
-- @param entities table to which entity data is written
-- @param params table to which parameter values are written
-- @param entitiesIndex number indicating the current index of entities
-- @param paramsIndex number indicating the current index of params
-- @param msgMap table mapping message ids to component maps
-- @return number entitiesIndex
-- @return number paramsIndex

function Shared.SerializeUpdate(instance, networkId, entities, params, entitiesIndex, paramsIndex, msgMap)
	local flags = 0
	local numDataStructs = 0
	local totalNumDataStructs = 0

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
				entitiesIndex, flags, numDataStructs = serializeKillComponent(
					entities, entitiesIndex
					map, flags
				)
			end

			totalNumDataStructs = totalNumDataStructs + numDataStructs
			msg = unsetbit(msgField, msg)
		end

		msgMap[msg] = nil
	end

	-- create header and increment entity table index
	entities[entitiesIndex - totalNumDataStructs] = Vector2int16.new(networkId, flags)
	entitesIndex = entitiesIndex + 1

	return entitiesIndex, paramsIndex
end

---Serializes a creation or destruction message for an entire entity
-- @param instance Instance to which the entity to be serialized is attached
-- @param networkId number signifying the networkId of this entity
-- @param entities table to which entity data is serialized
-- table entities:
--
--    { ..., Vector2int16[uint16 networkId, uint16 flags], Vector2int16[uint16 halfWord1, uint16 halfWord2], ...* }
--
--    *one additional Vector2int16 struct per non-zero componentId field word
--     (If this is a destruction message, zero additional Vector2int16s are created)
--
--------------------------------------------------------------------------------------------------------------------------------
-- uint16 flags:
--
--___F_______E_______D_______C_______B_______A_______9_______8_______7_______6_______5_______4_______3_______2_______1_______0 _
--   0   |   0   |   0   |   0   |   0   |   0       0       0       0       0       0       0       0       0   |   0       0  |
--       |       |       |       |       |                                                                       |              |
-- if set| if set| if set| if set| if set|                               n/a                                     |    cOffset   |
-- update| isRef |destroy| prefab| unique|                                                                       |              |
--------------------------------------------------------------------------------------------------------------------------------
--
-- @param params table to which parameter values are serialized
-- table params:
--
--    { ..., value, value, value, ...* }
--
--    *one additional value for each parameter on this entity, if applicable
--------------------------------------------------------------------------------------------------------------------------------
-- @param entitiesIndex number indicating current index of entities; initial value should be 1
-- @param paramsIndex number indicating current index of params; initial value should be 0
-- @param isDestruction boolean indicating whether this is a creation message or a destruction message
-- @param isReferenced boolean indicating whether this entity is referenced
-- @param isPrefab boolean indicating whether this entity belongs to a prefab
-- @param isUnique boolean indicating whether this is a uniquely replicated entity
-- @return number entitiesIndex
-- @return number paramsIndex

function Shared.SerializeEntity(instance, networkId, entities, params, entitiesIndex, paramsIndex, isDestruction, isReferenced, isPrefab, isUnique)
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

	flags = isReferenced and setbit(flags, IS_REFERENCED) or flags
	flags = isPrefab and setbit(flags, IS_PREFAB) or flags
	flags = isUnique and setbit(flags, IS_UNIQUE) or flags

	for fieldOffset, field in ipairs(entityStruct[0]) do
		if field ~= 0 then
			entitiesIndex = entitiesIndex + 1
			numDataStructs = numDataStructs + 1
			flags = setbit(flags, fieldOffset - 1)
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

	entities[entitiesIndex - numDataStructs] = Vector2int16.new(networkId, flags)
	entitiesIndex = entitiesIndex + 1

	return entitiesIndex, paramsIndex
end

---Deserializes the next message in entities
-- @param entities table containing serial entity data
-- @param params table containing serial param data
-- @param entitiesIndex number indicating current index in entities
-- @param paramsIndex number indicating current index in params
-- @param arg a prefab rootInstance or Player instance
-- @return variant

function Shared.DeserializeNext(entities, params, entitiesIndex, paramsIndex, arg)
	local header = entities[entitiesIndex]

	if invalidDataObj(header) then
		return
	end

	local networkId = bit32.bor(header.X, 0)
	local flags = header.Y
	local instance

	entities[entitiesIndex] = nil

	if isbitset(flags, UPDATE) then
		instance = InstancesByNetworkId[networkId]
		return deserializeUpdate(networkId, flags, entities, params, entitiesIndex, paramsIndex, instance, arg)
	else
		if IS_SERVER then
			return
		end

		return deserializeEntity(networkId, flags, entities, params, entitiesIndex, paramsIndex, arg)
	end
end

function Shared.QueueUpdate(instance, msgType, componentId, paramId)
	if BlacklistedComponents[componentId] then
		return
	end

	local messages = Queued[instance]

	if not messages then
		messages = {}
		Queued[instance] = messages
	end

	local msg = messages[msgType]

	if not msg then
		msg = {}
		messages[msgType] = msg
	end

	local field = msg[componentId]

	msg[componentId] = paramId and setbit(field or 0, paramId - 1) or true
end

function Shared.OnNewReference(instance, networkId)
	InstancesByNetworkId[networkId] = instance
	NetworkIdsByInstance[instance] = networkId
end

function Shared.OnDereference(instance, networkId)
	InstancesByNetworkId[networkId] = instance
	NetworkIdsByInstance[instance] = networkId
end

function Shared.Init(entityManager, entityMap, componentMap)
	EntityMap = entityMap
	ComponentMap = componentMap
	AddComponent = entityManager.AddComponent
	KillComponent = entityManager.KillComponent

	if IS_SERVER then
		Server = require(script.Parent.Server)
		BlacklistedComponents = Server.BlacklistedComponents
		PlayerSerializable = Server.PlayerSerializable
		PlayerCreatable = Server.PlayerCreatable
	end
end

return Shared


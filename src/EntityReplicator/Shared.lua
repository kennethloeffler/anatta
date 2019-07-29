-- Shared.lua

local Shared = {}

Shared._componentMap = nil
Shared._entityMap = nil

local bAnd = bit32.band
local bOr = bit32.bor
local bNot = bit32.bnot
local blShift = bit32.lshift
local bReplace = bit32.replace
local bExtract = bit32.extract

---Deserializes the construction message in entities at position entitiesIndex
-- @param entities table
-- @param params table
-- @param entitiesIndex number
-- @param paramsIndex number
-- @param bitFieldOffsets table
-- @param numBitFields number
-- @param flags uint16 field
-- @return number entitiesIndex
-- @return number paramsIndex
-- @return table componentIdsToParams
-- @return boolean isReferenced
local function deserializeConstructionMessage(entities, params, entitiesIndex, paramsIndex, bitFieldOffsets, numBitFields, flags)
	local dataObj = entities[entitiesIndex]
	local bitField = bReplace(dataObj.X, dataObj.Y, 16, 16)
	local bitFieldOffset = bitFieldOffsets[1]
	local componentId = 0
	local componentIdsToParams = {}

	for i = 1, numBitFields do
	
		for pos = 0, 31 do
			if bAnd(bitField, pos) ~= 0 then
				componentId = pos + 1 + (bitFieldOffset * 32)
				componentIdsToParams[componentId] = {}
				for i = 1, bExtract(flags, 4, 9) do
					paramsIndex = paramsIndex + 1
					componentIdsToParams[componentId][i] = params[paramsIndex]
				end
			end
		end

		if i + 1 < numBitFields then
			entitiesIndex = entitiesIndex + 1
			dataObj = entities[entitiesIndex]
			bitField = bReplace(dataObj.X, dataObj.Y, 16, 16)
			bitFieldOffset = bitFieldOffsets[i + 1]
		else
			break
		end
	end

	entitiesIndex = entitiesIndex + 1
	return entitiesIndex, paramsIndex, componentIdsToParams, bAnd(flags, 14)
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
-- @return boolean doAdd
-- @return boolean doKill
local function deserializeUpdateMessage(entities, params, entitiesIndex, paramsIndex, bitFieldOffsets, numBitFields, flags)
	local dataObj = entities[entitiesIndex]
	local bitField = bReplace(dataObj.X, dataObj.Y, 16, 16)
	local bitFieldOffset = bitFieldOffsets[1]
	local componentIdsToParams = {}
	local componentId = 0
	local numComponents = 0
	local index = ""

	for i = 1, numBitFields do
		for pos = 0, 31 do
			if bAnd(bitField, pos) ~= 0 then
				componentId = pos + 1 + (bitFieldOffset * 32)
				numComponents = numComponents + 1
				index = bAnd(numComponents, 1) == 0 and "Y" or "X"
				dataObj = entities[entitiesIndex + numBitFields - i + 1 + math.ceil(numComponents * 0.5)]
				bitField = dataObj[index]
				for paramId = 0, 15 do
					if bAnd(bitField, paramId) then
						paramsIndex = paramsIndex + 1
						componentIdsToParams[componentId][paramId + 1] = params[paramsIndex]
					end
				end
			end
		end

		if i + 1 < numBitFields then
			entitiesIndex = entitiesIndex + 1
			dataObj = entities[entitiesIndex]
			bitField = bReplace(dataObj.X, dataObj.Y, 16, 16)
			bitFieldOffset = bitFieldOffsets[i + 1]
		else
			break
		end
	end

	entitiesIndex = entitiesIndex + 1
	return entitiesIndex, paramsIndex, componentIdsToParams, bAnd(flags, 14) ~= 0, bAnd(flags, 13) ~= 0
end

-- sets the bit at position pos of n 
function Shared.SetBitAtPos(n, pos)
	local mask = blShift(1, pos)
	return bOr(bAnd(n, bNot(mask)), bAnd(blShift(pos), mask))
end

local setBitAtPos = Shared.setBitAtPos

---Calculates next char for id string
-- gsub function for getIdStringFromNum
local __IdLen, __IdNum = 0, 0
local function calcIdString()
	return string.char(__IdNum - ((__IdLen- 1) * 256) - 1)
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

---Serializes the creation or destruction of an entity
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
--___15______14______13______12______11______10______9_______8_______7_______6_______5_______4_______3_______2_______1_______0
--   0	 |   0   |   0   |   0       0       0       0       0       0       0       0       0   |   0       0       0       0
--       |       |       |                                                                       |                            |
-- if set| if set| if set|                               numParams                               |   nonZeroBitFieldIndices   |
-- update| isRef |destroy|                                                                       |                            |
------------------------------------------------------------------------------------------------------------------------------
--
--  [0, 3] : field representing indices of non-zero values of _entityMap[instance][0]
-- [4, 12] : 9-bit integer representing the total number of parameters on this entity [maximum 512 parameters per entity]
--           (unused if 14th bit is set)
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
--    *one additional value for each parameter on this entity
------------------------------------------------------------------------------------------------------------------------------
-- @param entitiesIndex number indicating current index of entities; initial value should be 1
-- @param paramsIndex number indicating current index of params; initial value should be 0
-- @param isDestruction boolean indicating whether this is a creation message or a destruction message
-- @param isReferenced boolean indicating whether this entity is referenced
-- @return number entitiesIndex
-- @return number paramsIndex
function Shared.SerializeNext(instance, networkId, entities, params, entitiesIndex, paramsIndex, isDestruction, isReferenced)
	local entityStruct = EntityReplicator._entityMap[instance]
	local bitFields = entityStruct[0]
	local flags = 0
	local numBitFields = 0
	local numParams = 0

	for offset, bitField in ipairs(bitFields) do
		if bitField ~= 0 then
			for pos = 0, 31 do
				if bAnd(bitField, pos) ~= 0 then	
					numParams = 0
					-- array part of component struct must be contigous!
					for _, v in ipairs(EntityReplicator._componentMap[entityStruct[pos + ((offset - 1) * 32))]) do
						paramsIndex = paramsIndex + 1
						numParams = numParams + 1
						params[paramsIndex] = v
					end
					-- set 5th through 13th bits to numParams
					flags = bReplace(flags, 4, numParams, 9)
				end
			end

			-- set nonZeroBitFieldIndices at position offset - 1 (offset <= 4)
			flags = setBitAtPos(flags, offset - 1)

			-- increment numBitFields, entitiesIndex; set component word in entities at entitiesIndex
			entitiesIndex = entitiesIndex + 1
			numBitFields = numBitFields + 1
			entities[entitiesIndex] = Vector2int16.new(bExtract(bitField, 0, 16), bExtract(bitField, 16, 16))
		end
	end
	
	if isDestruction then
		flags = setBitAtPos(flags, 13)
		entities[entitiesIndex] = Vector2int16.new(networkId, flags)
		entitiesIndex = entitiesIndex + 1
		return entitiesIndex, paramsIndex
	end

	if isReferenced then
		flags = setBitAtPos(flags, 14)
	end

	entities[entitiesIndex - numBitFields] = Vector2int16.new(networkId, flags)
	entitiesIndex = entitiesIndex + 1
	
	return entitiesIndex, paramsIndex
end

---Serializes the changes on the entity attached to instance
-- @param instance Instance to which this entity is attached
-- @param networkId number the networkId for this entity
-- @param entities table to which entity data is serialized
-- table entities:
--
--    { ..., Vector2int16[uint16 networkId, uint16 flags], 
--        Vector2int16[uint16 halfWord1, uint16 halfWord2], ...,* 
--        Vector2int16[uint16 paramField1, uint16 paramField2], ...**
--    } 
--    
--    * one (1) additional Vector2int16 struct per non-zero component word
--    ** one (1) additional Vector2int16 struct per two (2) changed components [max sixteen (16) parameters per component]

-- uint16 flags:

--___15______14______13______12______11______10______9_______8_______7_______6_______5_______4_______3_______2_______1_______0
--   0	 |   0   |   0   |   0       0       0       0       0       0       0       0       0   |   0       0       0       0
--       |       |       |                                                                       |                            |
-- if set| if set| if set|                                 (unused)                              |   nonZeroBitFieldIndices   |
-- update|  add  |  kill |                                                                       |                            |
-------------------------------------------------------------------------------------------------------------------------------
--
--   [0, 3] : field representing indices of non-zero component fields
-- [4 , 12] : N/A
--      13  : bit representing whether this is a kill component message
--      14  : bit representing whether this is an add component message
--      15  : bit representing whether this is an update message
--            (always set for messages generated by this function)
------------------------------------------------------------------------------------------------------------------------------
-- @param params table to which parameter values are serialized
-- table params:
--
--    { ..., value, value, ...* }
--
--    * one (1) additional value per parameter
------------------------------------------------------------------------------------------------------------------------------
-- @param entitiesIndex number indicating the current index of entities
-- @param paramsIndex number indicating the current index of params
-- @param changedParamsMap table mapping component ids to changed parameter fields
-- @return number entitiesIndex
-- @return number paramsIndex
function Shared.SerializeNextUpdate(instance, networkId, entities, params, entitiesIndex, paramsIndex, changedParamsMap, add, kill)
	local entityStruct = Shared._entityMap[instance]
	local flags = 0
	local numDataStructs = 0
	local numParamStructs = 0	
	local numBitFields = 0
	local numComponents = 0
	local currentComponentId = 0
	local lastComponentId = 0
	local bitFields = {0, 0, 0, 0}

	for componentId, changedParams in pairs(changedParamsMap) do
		local offset = math.ceil(componentId * 0.03125) -- componentId / 32
		bitFields[offset] = setBitAtPos(bitFields[offset], componentId - 1 + (32 * (offset - 1)))
		numBitFields = offset
		flags = setBitAtPos(flags, offset - 1)
	end

	for offset, bitField in ipairs(bitFields) do
		local componentOffset = 32 * (offset - 1)
		if bitField ~= 0 then
			entitiesIndex = entitiesIndex + 1
			numDataStructs = numDataStructs + 1
			entitiesIndex[entitiesIndex] = Vector2int16.new(bExtract(bitField, 0, 16), bExtract(bitField, 16, 16))
			for pos = 0, 31 do
				if bAnd(bitField, pos) ~= 0 then
					numComponents = numComponents + 1
					currentComponentId = pos + 1 + componentOffset
					if bAnd(numComponents, 1) ~= 0 then
						numParamStructs = numParamStructs + 1
						numDataStructs = numDataStructs + 1
						numComponents = 0
						entities[entitiesIndex + numBitFields + numParamStructs] = Vector2int16.new(changedParamsMap[lastComponentId], changedParamsMap[currentComponentId])
						for paramId = 0, 15 do
							if bAnd(changedParamsMap[lastComponentId], paramId) ~= 0 then
								paramsIndex = paramsIndex + 1
								params[paramsIndex] = Shared._componentMap[lastComponentId][entityStruct[lastComponentId]][paramId + 1]
							end
						end
					else
						for paramId = 0, 15 do
							if bAnd(changedParamsMap[currentComponentId], paramId) ~= 0 then
								paramsIndex = paramsIndex + 1
								params[paramsIndex] = Shared._componentMap[currentComponentId][entityStruct[currentComponentId]][paramId + 1]
							end
						end
						lastComponentId = currentComponentId
					end
				end
			end
		end
	end

	if add then
		flags = setBitAtPos(flags, 14)
	end

	if kill then
		flags = setBitAtPos(flags, 13)
	end

	flags = setBitAtPos(flags, 15)
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

	-- this is a destruction message; return nil for componentIdsToParams
	if bAnd(flags, 14) ~= 0 then
		entitiesIndex = entitiesIndex + 1
		return networkId, nil, entitiesIndex, paramsIndex
	end

	-- this is either an update message or a construction message; collect component field offsets
	for pos = 0, 3 do
		if bAnd(flags, pos) ~= 0 then
			numBitFields = numBitFields + 1
			bitFieldOffsets[numBitFields] = pos
		end
	end

	-- this is an update message
	if bAnd(flags, 15) ~= 0 then
		entitiesIndex = entitiesIndex + 1
		entitiesIndex, paramsIndex, componentIdsToParams, doAdd, doKill = deserializeUpdateMessage(entities, params, entitiesIndex, paramsIndex, bitFieldOffsets, numBitFields, flags)
		return networkId, componentIdsToParams, entitiesIndex, paramsIndex, nil, nil, true, doAdd, doKill
	end

	-- haven't returned yet; this is an entity construction message
	entitiesIndex = entitiesIndex = 1
	entitiesIndex, paramsIndex, componentIdsToParams, isReferenced = deserializeConstructionMessage(entities, params, entitiesIndex, paramsIndex, bitFieldOffsets, numBitFields, flags)

	return networkId, componentIdsToParams, entitiesIndex, paramsIndex, bAnd(flags, 14) ~= 0
end

function Shared.Init(entityMap, componentMap)
	Shared._entityMap = entityMap
	Shared._componentMap = componentMap
end

return Shared


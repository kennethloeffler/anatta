local Constants = require(script.Parent.Parent.Constants)

local DEBUG = Constants.DEBUG

-- set can contain values on the range [1, VALUE_MASK]
local VALUE_MASK = require(script.Parent.Parent.Constants).ENTITYID_MASK

local ErrOutOfRange = "out of range"
local ErrDoesntExist = "set does not contain this value"
local ErrAlreadyExists = "set already contains this value"

local has

local SparseSet = {}

-- create a new empty sparse set and return it
function SparseSet.new()
	return {
		External = {},
		Internal = {},
		Size = 0
	}
end

--[[

 If a set contains the value, return its index in the set's internal
 array; otherwise, return nil

]]
function SparseSet.Has(set, value)
	if DEBUG then
		assert(bit32.band(value, VALUE_MASK) <= VALUE_MASK, ErrOutOfRange)
	end

	local externalIndex = bit32.band(value, VALUE_MASK)
	local internalIndex = set.External[externalIndex]

	if internalIndex and internalIndex <= set.Size then
		return internalIndex
	end
end

has = SparseSet.Has

--[[

 Insert the value into a set. Insertion of a value which already
 exists in a set is undefined

]]
function SparseSet.Insert(set, value)
	if DEBUG then
		assert(bit32.band(value, VALUE_MASK) <= VALUE_MASK, ErrOutOfRange)
		assert(not has(set, value), ErrAlreadyExists)
	end

	local size = set.Size + 1
	local externalIndex = bit32.band(value, VALUE_MASK)

	set.Size = size
	set.Internal[size] = value
	set.External[externalIndex] = size
end

--[[

 Remove the value from a set

 Removal of a value which does not exist in the set is undefined.

]]
function SparseSet.Remove(set, value)
	if DEBUG then
		assert(bit32.band(value, VALUE_MASK) <= VALUE_MASK, ErrOutOfRange)
		assert(has(set, value), ErrDoesntExist)
	end

	local internal = set.Internal
	local external = set.External
	local externalIndex = bit32.band(value, VALUE_MASK)
	local internalIndex = external[externalIndex]
	local size = set.Size - 1

	set.Size = size

	if size ~= 0 then
		local swappedExternal = table.remove(internal)

		internal[internalIndex] = swappedExternal
		external[swappedExternal] = internalIndex
	else
		internal[internalIndex] = nil
	end

	external[externalIndex] = nil

	return internalIndex
end

return SparseSet

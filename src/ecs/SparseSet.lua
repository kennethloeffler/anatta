local Constants = require(script.Parent.Parent.Constants)

local DEBUG = Constants.DEBUG

-- set can contain values on the range [1, VALUE_MASK]
local VALUE_MASK = require(script.Parent.Parent.Constants).ENTITYID_MASK

local ErrOutOfRange = "out of range"
local ErrDoesntExist = "set does not contain this value"
local ErrAlreadyExists = "set already contains this value"

local has

local SparseSet = {}

--[[

 Create a new empty sparse set and return it

]]
function SparseSet.new()
	return {
		external = {},
		internal = {},
		size = 0
	}
end

--[[

 If the set contains the value, return its index into the set's internal
 array; otherwise, return nil

]]
function SparseSet.has(set, value)
	if DEBUG then
		assert(bit32.band(value, VALUE_MASK) <= VALUE_MASK, ErrOutOfRange)
	end

	local externalIndex = bit32.band(value, VALUE_MASK)
	local internalIndex = set.external[externalIndex]

	if internalIndex and internalIndex <= set.size then
		return internalIndex
	end
end

has = SparseSet.has

--[[

<<<<<<< HEAD
 Insert the value into a set and return the set's new size. insertion
 of a value which already exists in a set is undefined
=======
 Insert the value into the set. Insertion of a value which already
 exists in the set is undefined
>>>>>>> 6a53b5a873d3b3b550eb2e3b0da98ba74b57f505

]]
function SparseSet.insert(set, value)
	if DEBUG then
		assert(bit32.band(value, VALUE_MASK) <= VALUE_MASK, ErrOutOfRange)
		assert(not has(set, value), ErrAlreadyExists)
	end

	local size = set.size + 1
	local externalIndex = bit32.band(value, VALUE_MASK)

	set.size = size
	set.internal[size] = value
	set.external[externalIndex] = size

	return size
end

--[[

 Remove the value from the set. Removal of a value which does not
 exist in the set is undefined

]]
function SparseSet.remove(set, value)
	if DEBUG then
		assert(bit32.band(value, VALUE_MASK) <= VALUE_MASK, ErrOutOfRange)
		assert(has(set, value), ErrDoesntExist)
	end

	local internal = set.internal
	local external = set.external
	local externalIndex = bit32.band(value, VALUE_MASK)
	local internalIndex = external[externalIndex]
	local size = set.size

	set.size = size - 1

	if size > 1 then
		local swappedExternal = internal[size]

		internal[internalIndex] = swappedExternal
		external[swappedExternal] = internalIndex
	else
		internal[internalIndex] = nil
	end

	external[externalIndex] = nil

	return internalIndex
end

return SparseSet

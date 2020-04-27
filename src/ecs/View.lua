local Constants = require(script.Parent.Parent.Constants)
local Pool = require(script.Parent.Pool)

local View = {}

local Multi = {}
Multi.__index = Multi

local MultiWithExcluded = {}
MultiWithExcluded.__index = MultiWithExcluded

local Single = {}
Single.__index = Single

local SingleWithExcluded = {}
SingleWithExcluded.__index = SingleWithExcluded

local selectShortestPool
local hasIncluded
local doesntHaveExcluded
local hasIncludedThenPack

local has = Pool.Has
local get = Pool.Get

function View.new(included, excluded)
	local numIncluded = #included
	local viewKind = numIncluded == 1
		and (excluded and SingleWithExcluded or Single)
		or (excluded and MultiWithExcluded or Multi)

	return setmetatable({
		Included = numIncluded > 1 and included or included[1],
		Excluded = excluded,
		ComponentPack = {} -- table.create(numIncluded)
	}, viewKind)
end

function Multi:ForEach(func)
	local pack = self.ComponentPack
	local included = self.Included
	local shortestPool = selectShortestPool(included)

	for _, entity in ipairs(shortestPool.Internal) do
		if hasIncludedThenPack(entity, included, pack) then
			func(entity, unpack(pack))
		end
	end
end

function Multi:ForEachEntity(func)
	local included = self.Included
	local shortestPool = selectShortestPool(included)

	for _, entity in ipairs(shortestPool.Internal) do
		if hasIncluded(entity, included, shortestPool) then
			func(entity)
		end
	end
end

function Multi:Has(entity)
	for _, pool in ipairs(self.Included) do
		if not has(pool, entity) then
			return false
		end
	end

	return true
end

function Single:ForEach(func)
	local pool = self.Included
	local objs = pool.Objects

	for index, entity in ipairs(pool.Internal) do
		func(entity, objs[index])
	end
end

function Single:ForEachEntity(func)
	for _, entity in ipairs(self.Included.Internal) do
		func(entity)
	end
end

function Single:ForEachComponent(func)
	for _, component in ipairs(self.Included.Objects) do
		func(component)
	end
end

--[[

 For each entity in the view, call the function FUNC; the entity
 followed by the components specified by the view are passed as
 arguments. The order of the parameterized components with respect to
 each other is the same as their order in the view's contructor

]]
function MultiWithExcluded:ForEach(func)
	local pack = self.ComponentPack
	local included = self.Included
	local excluded = self.Excluded
	local shortestPool = selectShortestPool(included)

	for _, entity in ipairs(shortestPool.Internal) do
		if hasIncludedThenPack(entity, included, pack)
		and doesntHaveExcluded(entity, excluded) then
			func(entity, unpack(pack))
		end
	end
end

-- same as above, but only pass the entity
function MultiWithExcluded:ForEachEntity(func)
	local included = self.Included
	local excluded = self.Excluded
	local shortestPool = selectShortestPool(included)

	for _, entity in ipairs(shortestPool.Internal) do
		if hasIncluded(entity, included, shortestPool) and
		doesntHaveExcluded(entity, excluded) then
			func(entity)
		end
	end
end

function MultiWithExcluded:Has(entity)
	local excluded = self.Excluded

	for _, pool in ipairs(self.Included) do
		if not has(pool, entity) or not doesntHaveExcluded(entity, excluded) then
			return false
		end
	end

	return true
end

function SingleWithExcluded:ForEach(func)
	local included = self.Included
	local excluded = self.Excluded
	local objects = included.Objects

	for index, entity in ipairs(included.Internal) do
		if doesntHaveExcluded(entity, excluded) then
			func(entity, objects[index])
		end
	end
end

function SingleWithExcluded:ForEachEntity(func)
	local included = self.Included
	local excluded = self.Excluded

	for _, entity in ipairs(included.Internal) do
		if doesntHaveExcluded(entity, excluded) then
			func(entity)
		end
	end
end

function SingleWithExcluded:ForEachComponent(func)
	local included = self.Included
	local excluded = self.Excluded
	local objs = included.Objects

	for index, entity in ipairs(included.Internal) do
		if doesntHaveExcluded(entity, excluded) then
			func(entity, objs[index])
		end
	end
end

function SingleWithExcluded:Has(entity)
	local excluded = self.Excluded

	return has(self.Included, entity) and doesntHaveExcluded(entity, excluded)
end

selectShortestPool = function(pools)
	local _, candidate = next(pools)

	for _, pool in ipairs(pools) do
		if pool.Size < candidate.Size then
			candidate = pool
		end
	end

	return candidate
end

doesntHaveExcluded = function(entity, excluded)
	for _, pool in ipairs(excluded) do
		if has(pool, entity) then
			return false
		end
	end

	return true
end

hasIncluded = function(entity, included)
	for _, includedPool in ipairs(included) do
		if not has(includedPool, entity) then
			return false
		end
	end

	return true
end

hasIncludedThenPack = function(entity, included, pack)
	local obj

	for i, includedPool in ipairs(included) do
		obj = get(includedPool, entity)

		if not obj then
			return false
		end

		pack[i] = obj
	end

	return true
end

if Constants.DEBUG then
	View._singleMt = Single
	View._singleWithExclMt = SingleWithExcluded
	View._multiMt = Multi
	View._multiWithExclMt = MultiWithExcluded

	View._selectShortestPool = selectShortestPool
	View._doesntHaveExcluded = doesntHaveExcluded
	View._hasIncluded = hasIncluded
	View._hasIncludedThenPack = hasIncludedThenPack
end

return View

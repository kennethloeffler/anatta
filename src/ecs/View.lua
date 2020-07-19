local Constants = require(script.Parent.Constants)
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

local has = Pool.has

function View.new(included, excluded)
	local numIncluded = #included
	local viewKind = numIncluded == 1
		and (excluded and SingleWithExcluded or Single)
		or (excluded and MultiWithExcluded or Multi)

	return setmetatable({
		included = numIncluded > 1 and included or included[1],
		excluded = excluded,
		componentPack = {} -- table.create(numIncluded)
	}, viewKind)
end

function Multi:forEach(func)
	local pack = self.componentPack
	local included = self.included
	local shortestPool = selectShortestPool(included)

	for _, entity in ipairs(shortestPool.dense) do
		if hasIncludedThenPack(entity, included, pack) then
			func(entity, unpack(pack))
		end
	end
end

function Multi:forEachEntity(func)
	local included = self.included
	local shortestPool = selectShortestPool(included)

	for _, entity in ipairs(shortestPool.dense) do
		if hasIncluded(entity, included, shortestPool) then
			func(entity)
		end
	end
end

function Multi:has(entity)
	for _, pool in ipairs(self.included) do
		if not has(pool, entity) then
			return false
		end
	end

	return true
end

function Single:forEach(func)
	local pool = self.included
	local objs = pool.objects

	for index, entity in ipairs(pool.dense) do
		func(entity, objs[index])
	end
end

function Single:forEachEntity(func)
	for _, entity in ipairs(self.included.dense) do
		func(entity)
	end
end

--[[

 For each entity in the view, call the function FUNC; the entity
 followed by the components specified by the view are passed as
 arguments. the order of the parameterized components with respect to
 each other is the same as their order in the view's contructor

]]
function MultiWithExcluded:forEach(func)
	local pack = self.componentPack
	local included = self.included
	local excluded = self.excluded
	local shortestPool = selectShortestPool(included)

	for _, entity in ipairs(shortestPool.dense) do
		if doesntHaveExcluded(entity, excluded) and
		hasIncludedThenPack(entity, included, pack) then
			func(entity, unpack(pack))
		end
	end
end

-- same as above, but only pass the entity
function MultiWithExcluded:forEachEntity(func)
	local included = self.included
	local excluded = self.excluded
	local shortestPool = selectShortestPool(included)

	for _, entity in ipairs(shortestPool.dense) do
		if hasIncluded(entity, included, shortestPool) and
		doesntHaveExcluded(entity, excluded) then
			func(entity)
		end
	end
end

function MultiWithExcluded:has(entity)
	local excluded = self.excluded

	for _, pool in ipairs(self.included) do
		if not has(pool, entity) or not doesntHaveExcluded(entity, excluded) then
			return false
		end
	end

	return true
end

function SingleWithExcluded:forEach(func)
	local included = self.included
	local excluded = self.excluded
	local objects = included.objects

	for index, entity in ipairs(included.dense) do
		if doesntHaveExcluded(entity, excluded) then
			func(entity, objects[index])
		end
	end
end

function SingleWithExcluded:forEachEntity(func)
	local included = self.included
	local excluded = self.excluded

	for _, entity in ipairs(included.dense) do
		if doesntHaveExcluded(entity, excluded) then
			func(entity)
		end
	end
end

function SingleWithExcluded:has(entity)
	local excluded = self.excluded

	return has(self.included, entity) and doesntHaveExcluded(entity, excluded)
end

selectShortestPool = function(pools)
	local _, candidate = next(pools)

	for _, pool in ipairs(pools) do
		if pool.size < candidate.size then
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
	local index

	for i, includedPool in ipairs(included) do
		index = has(includedPool, entity)

		if not index then
			return false
		end

		pack[i] = includedPool.objects and includedPool.objects[index]
	end

	return true
end

if Constants.STRICT then
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

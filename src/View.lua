local Matcher = require(script.Parent.Matcher)

local View = {}
View.__index = Matcher

local Multi = {}
Multi.__index = Multi

local MultiWithForbidden = {}
MultiWithForbidden.__index = MultiWithForbidden

local Single = {}
Single.__index = Single

local SingleWithForbidden = {}
SingleWithForbidden.__index = SingleWithForbidden

local function selectShortestPool(pools)
	local _, candidate = next(pools)

	for _, pool in ipairs(pools) do
		if pool.size < candidate.size then
			candidate = pool
		end
	end

	return candidate
end

local function doesntHaveForbidden(entity, forbidden)
	for _, pool in ipairs(forbidden) do
		if pool:has(entity) then
			return false
		end
	end

	return true
end

local function hasRequired(entity, required)
	for _, requiredPool in ipairs(required) do
		if not requiredPool:has(entity) then
			return false
		end
	end

	return true
end

local function hasRequiredThenPack(entity, required, pack)
	local index

	for i, requiredPool in ipairs(required) do
		index = requiredPool:has(entity)

		if not index then
			return false
		end

		pack[i] = requiredPool.objects and requiredPool.objects[index]
	end

	return true
end

function View.new(manifest)
	return setmetatable({
		manifest = manifest,

		required = {},
		forbidden = {},
		changed = {},
	}, View)
end

function View:__call()
	local numRequired = #self.required
	local forbidden = #self.forbidden > 0

	local viewKind = numRequired == 1
		and (forbidden and SingleWithForbidden or Single)
		or (forbidden and MultiWithForbidden or Multi)

	self.componentPack = table.create and table.create(numRequired) or {}

	for i, id in ipairs(self.required) do
		self.required[i] = self.manifest:_getPool(id)
	end

	for i, id in ipairs(self.forbidden) do
		self.forbidden[i] = self.manifest:_getPool(id)
	end

	return setmetatable(self, viewKind)
end

function Multi:forEach(func)
	local pack = self.componentPack
	local required = self.required
	local shortestPool = selectShortestPool(required)

	for _, entity in ipairs(shortestPool.dense) do
		if hasRequiredThenPack(entity, required, pack) then
			func(entity, unpack(pack))
		end
	end
end

function Multi:forEachEntity(func)
	local required = self.required
	local shortestPool = selectShortestPool(required)

	for _, entity in ipairs(shortestPool.dense) do
		if hasRequired(entity, required, shortestPool) then
			func(entity)
		end
	end
end

function Multi:has(entity)
	for _, pool in ipairs(self.required) do
		if not pool:has(entity) then
			return false
		end
	end

	return true
end

function Single:forEach(func)
	local pool = self.required[1]
	local objs = pool.objects

	for index, entity in ipairs(pool.dense) do
		func(entity, objs[index])
	end
end

function Single:forEachEntity(func)
	for _, entity in ipairs(self.required[1].dense) do
		func(entity)
	end
end

function MultiWithForbidden:forEach(func)
	local pack = self.componentPack
	local required = self.required
	local forbidden = self.forbidden
	local shortestPool = selectShortestPool(required)

	for _, entity in ipairs(shortestPool.dense) do
		if doesntHaveForbidden(entity, forbidden) and
		hasRequiredThenPack(entity, required, pack) then
			func(entity, unpack(pack))
		end
	end
end

function MultiWithForbidden:forEachEntity(func)
	local required = self.required
	local forbidden = self.forbidden
	local shortestPool = selectShortestPool(required)

	for _, entity in ipairs(shortestPool.dense) do
		if hasRequired(entity, required, shortestPool) and
		doesntHaveForbidden(entity, forbidden) then
			func(entity)
		end
	end
end

function MultiWithForbidden:has(entity)
	local forbidden = self.forbidden

	for _, pool in ipairs(self.required) do
		if not pool:has(entity) or not doesntHaveForbidden(entity, forbidden) then
			return false
		end
	end

	return true
end

function SingleWithForbidden:forEach(func)
	local required = self.required[1]
	local forbidden = self.forbidden
	local objects = required.objects

	for index, entity in ipairs(required.dense) do
		if doesntHaveForbidden(entity, forbidden) then
			func(entity, objects[index])
		end
	end
end

function SingleWithForbidden:forEachEntity(func)
	local required = self.required[1]
	local forbidden = self.forbidden

	for _, entity in ipairs(required.dense) do
		if doesntHaveForbidden(entity, forbidden) then
			func(entity)
		end
	end
end

function SingleWithForbidden:has(entity)
	local forbidden = self.forbidden

	return self.required:has(entity) and doesntHaveForbidden(entity, forbidden)
end

View._singleMt = Single
View._singleWithExclMt = SingleWithForbidden
View._multiMt = Multi
View._multiWithExclMt = MultiWithForbidden

View._selectShortestPool = selectShortestPool
View._doesntHaveForbidden = doesntHaveForbidden
View._hasRequired = hasRequired
View._hasRequiredThenPack = hasRequiredThenPack

return View

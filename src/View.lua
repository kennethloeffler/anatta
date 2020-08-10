local Matcher = require(script.Parent.Matcher)

local EMPTY = {}

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

	self.componentPack = table.create(numRequired)

	return setmetatable(self, viewKind)
end

local function selectShortestPool(manifest, required)
	local _, candidate = next(required)

	for _, id in ipairs(required) do
		if manifest:poolSize(id) < manifest:poolSize(candidate) then
			candidate = id
		end
	end

	return manifest:_getPool(candidate)
end

function Multi:forEach(func)
	for _, entity in ipairs(
		selectShortestPool(self.manifest, self.required).dense
	) do
		if self.manifest:has(entity, unpack(self.required)) then
			func(entity, self.manifest:multiGet(
					entity,
					self.componentPack,
					unpack(self.required)
				)
			)
		end
	end
end

function Multi:forEachEntity(func)
	for _, entity in ipairs(
		selectShortestPool(self.manifest, self.required).dense
	) do
		if self.manifest:has(entity, unpack(self.required)) then
			func(entity)
		end
	end
end

function Multi:has(entity)
	return self.manifest:has(entity, unpack(self.required))
end

function Single:forEach(func)
	local pool = self.manifest:_getPool(self.required[1])

	for index, entity in ipairs(pool.dense) do
		func(entity, pool.objects[index])
	end
end

function Single:forEachEntity(func)
	for _, entity in ipairs(self.manifest:_getPool(self.required[1]).dense) do
		func(entity)
	end
end

function Single:consume(func)
	local pool = self.manifest:_getPool(self.required[1])

	for _, entity in ipairs(pool.dense) do
		func(entity)
		pool.sparse[entity] = nil
	end

	table.move(EMPTY, 1, #pool.dense, 1, pool.dense)
	table.move(EMPTY, 1, #pool.objects, 1, pool.objects)

	pool.size = 0
end

function MultiWithForbidden:forEach(func)
	for _, entity in ipairs(
		selectShortestPool(self.manifest, self.required).dense
	) do
		if not self.manifest:any(entity, unpack(self.forbidden))
		and self.manifest:has(entity, unpack(self.required)) then
			func(entity, self.manifest:multiGet(
					entity,
					self.componentPack,
					unpack(self.required)
				)
			)
		end
	end
end

function MultiWithForbidden:forEachEntity(func)
	for _, entity in ipairs(
		selectShortestPool(self.manifest, self.required).dense
	) do
		if not self.manifest:any(entity, unpack(self.forbidden))
		and self.manifest:has(entity, unpack(self.required)) then
			func(entity)
		end
	end
end

function MultiWithForbidden:has(entity)
	return not self.manifest:any(entity, unpack(self.forbidden))
		and self.manifest:has(entity, unpack(self.required))
end

function SingleWithForbidden:forEach(func)
	local pool = self.manifest:_getPool(self.required[1])

	for index, entity in ipairs(pool.dense) do
		if not self.manifest:any(entity, unpack(self.forbidden)) then
			func(entity, pool.objects[index])
		end
	end
end

function SingleWithForbidden:forEachEntity(func)
	for _, entity in ipairs(
		self.manifest:_getPool(self.required[1]).dense
	) do
		if not self.manifest:any(entity, unpack(self.forbidden)) then
			func(entity)
		end
	end
end

function SingleWithForbidden:consume(func)
	local pool = self.manifest:_getPool(self.required[1])

	for _, entity in ipairs(pool.dense) do
		if not self.manifest:any(entity, unpack(forbidden)) then
			func(entity)
			pool.sparse[entity] = nil
		end
	end

	table.move(EMPTY, 1, pool.size, 1, pool.dense)
	table.move(EMPTY, 1, pool.size, 1, pool.objects)

	pool.size = 0
end

function SingleWithForbidden:has(entity)
	return self.manifest:has(entity, unpack(self.required))
		and not self.manifest:any(entity, unpack(self.forbidden))
end

View._singleMt = Single
View._singleWithExclMt = SingleWithForbidden
View._multiMt = Multi
View._multiWithExclMt = MultiWithForbidden
View._selectShortestPool = selectShortestPool

return View

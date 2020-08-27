local NONE = {}

local Multi = {}
Multi.__index = Multi

local MultiWithForbidden = {}
MultiWithForbidden.__index = MultiWithForbidden

local Single = {}
Single.__index = Single

local SingleWithForbidden = {}
SingleWithForbidden.__index = SingleWithForbidden

local View = {}

function View.new(constraint)
	local manifest = constraint.manifest
	local numRequired = #constraint.required
	local numForbidden = #constraint.forbidden

	local viewKind = numRequired == 1
		and (numForbidden > 0 and SingleWithForbidden or Single)
		or (numForbidden > 0 and MultiWithForbidden or Multi)

	constraint.componentPack = table.create(numRequired)

	for i, id in ipairs(constraint.required) do
		constraint.required[i] = manifest:_getPool(id)
	end

	for i, id in ipairs(constraint.forbidden) do
		constraint.forbidden[i] = manifest:_getPool(id)
	end

	return setmetatable(constraint, viewKind)
end

local function selectShortestPool(required)
	local _, candidate = next(required)

	for _, pool in ipairs(required) do
		if pool.size < candidate.size then
			candidate = pool
		end
	end

	return candidate
end

local function size(view)
	return selectShortestPool(view.required)
end

function Multi:each(func)
	local required = self.required
	local componentPack = self.componentPack

	for _, entity in ipairs(selectShortestPool(required).dense) do
		local hasRequired = true
		for i, pool in ipairs(required) do
			local idx = pool.sparse[entity]

			if not idx then
				hasRequired = false
				break
			end

			componentPack[i] = pool.objects[idx]
		end

		if hasRequired then
			func(entity, unpack(componentPack))
		end
	end
end

function Multi:eachEntity(func)
	local required = self.required

	for _, entity in ipairs(selectShortestPool(required).dense) do
		local hasRequired = true
		for i, pool in ipairs(required) do
			if not pool.sparse[entity] then
				hasRequired = false
				break
			end
		end

		if hasRequired then
			func(entity)
		end
	end
end

Multi.size = size

function Single:each(func)
	local pool = self.required[1]

	for i, entity in ipairs(pool.dense) do
		func(entity, pool.objects[i])
	end
end

function Single:eachEntity(func)
	for _, entity in ipairs(self.required[1].dense) do
		func(entity)
	end
end

function Single:consume(func)
	local pool = self.required[1]
	local dense = pool.dense
	local sparse = pool.sparse

	if func then
		for _, entity in ipairs(dense) do
			func(entity)
		end
	end

	for entity in pairs(sparse) do
		sparse[entity] = nil
	end

	table.move(NONE, 1, pool.size, 1, dense)
	table.move(NONE, 1, pool.size, 1, pool.objects)
	pool.size = 0
end

Single.size = size

function MultiWithForbidden:each(func)
	local required = self.required
	local forbidden = self.forbidden
	local componentPack = self.componentPack

	for _, entity in ipairs(selectShortestPool(required).dense) do
		local hasForbidden = false
		local hasRequired = true

		for i, pool in ipairs(forbidden) do
			if pool.sparse[entity] then
				hasForbidden = true
				break
			end
		end

		if hasForbidden then
			continue
		end

		for i, pool in ipairs(required) do
			local idx = pool.sparse[entity]

			if not idx then
				hasRequired = false
				break
			end

			componentPack[i] = pool.objects[idx]
		end

		if hasRequired then
			func(entity, unpack(componentPack))
		end
	end
end

function MultiWithForbidden:eachEntity(func)
	local required = self.required
	local forbidden = self.forbidden
	local componentPack = self.componentPack

	for _, entity in ipairs(selectShortestPool(required).dense) do
		local hasForbidden = false
		local hasRequired = true

		for i, pool in ipairs(forbidden) do
			if pool.sparse[entity] then
				hasForbidden = true
				break
			end
		end

		if hasForbidden then
			continue
		end

		for i, pool in ipairs(required) do
			local idx = pool.sparse[entity]

			if not idx then
				hasRequired = false
				break
			end

			componentPack[i] = pool.objects[idx]
		end

		if hasRequired then
			func(entity, unpack(componentPack))
		end
	end
end

MultiWithForbidden.size = size

function SingleWithForbidden:each(func)
	local objects = self.required[1].objects
	local forbidden = self.forbidden

	for idx, entity in ipairs(self.required[1].dense) do
		local hasForbidden = false

		for i, pool in ipairs(forbidden) do
			if pool.sparse[entity] then
				hasForbidden = true
				break
			end
		end

		if hasForbidden then
			continue
		end

		func(entity, objects[idx])
	end
end

function SingleWithForbidden:eachEntity(func)
	local forbidden = self.forbidden

	for _, entity in ipairs(self.required[1].dense) do
		local hasForbidden = false

		for i, pool in ipairs(forbidden) do
			if pool.sparse[entity] then
				hasForbidden = true
				break
			end
		end

		if hasForbidden then
			continue
		end

		func(entity)
	end
end

SingleWithForbidden.size = size

View._singleMt = Single
View._singleWithExclMt = SingleWithForbidden
View._multiMt = Multi
View._multiWithExclMt = MultiWithForbidden
View._selectShortestPool = selectShortestPool

return View

local Constants = require(script.Parent.Constants)

local ENTITYID_MASK = Constants.ENTITYID_MASK
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
		constraint.required[i] = manifest:getPool(id)
	end

	for i, id in ipairs(constraint.forbidden) do
		constraint.forbidden[i] = manifest:getPool(id)
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
	return selectShortestPool(view.required).size
end

function Multi:each(func)
	local required = self.required
	local componentPack = self.componentPack

	for _, entity in ipairs(selectShortestPool(required).dense) do
		local entityId = bit32.band(entity, ENTITYID_MASK)
		local hasRequired = true
		for i, pool in ipairs(required) do
			local idx = pool.sparse[entityId]

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

function Multi:mutEach(func)
	local required = self.required
	local componentPack = self.componentPack
	local shortestPool = selectShortestPool(required)
	local dense = shortestPool.dense

	-- shortest pool is being completely consumed this iteration
	for i = shortestPool.size, 1, -1 do
		local hasRequired = true
		local entity = dense[i]
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for k, pool in ipairs(required) do
			local idx = pool.sparse[entityId]

			if not idx then
				hasRequired = false
				break
			end

			componentPack[k] = pool.objects[idx]
		end

		if hasRequired then
			func(entity, unpack(componentPack))
		end
	end
end

function Multi:eachEntity(func)
	local required = self.required

	for _, entity in ipairs(selectShortestPool(required).dense) do
		local entityId = bit32.band(entity, ENTITYID_MASK)
		local hasRequired = true
		for _, pool in ipairs(required) do
			if not pool.sparse[entityId] then
				hasRequired = false
				break
			end
		end

		if hasRequired then
			func(entity)
		end
	end
end

function Multi:mutEachEntity(func)
	local required = self.required
	local shortestPool = selectShortestPool(required)
	local dense = shortestPool.dense

	for i = shortestPool.size, 1, -1 do
		local hasRequired = true
		local entity = dense[i]
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, pool in ipairs(required) do
			if not pool.sparse[entityId] then
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
	local objects = pool.objects

	for i, entity in ipairs(pool.dense) do
		func(entity, objects[i])
	end
end

function Single:mutEach(func)
	local pool = self.required[1]
	local objects = pool.objects
	local dense = pool.dense

	for i = pool.size, 1, -1 do
		func(dense[i], objects[i])
	end
end

function Single:eachEntity(func)
	for _, entity in ipairs(self.required[1].dense) do
		func(entity)
	end
end

function Single:mutEachEntity(func)
	local pool = self.required[1]
	local dense = pool.dense

	for i = pool.size, 1, -1 do
		func(dense[i])
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
		sparse[bit32.band(entity, ENTITYID_MASK)] = nil
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
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, pool in ipairs(forbidden) do
			if pool.sparse[entityId] then
				hasForbidden = true
				break
			end
		end

		if hasForbidden then
			continue
		end

		for i, pool in ipairs(required) do
			local idx = pool.sparse[entityId]

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

function MultiWithForbidden:mutEach(func)
	local required = self.required
	local forbidden = self.forbidden
	local componentPack = self.componentPack
	local shortestPool = selectShortestPool(required)
	local dense = shortestPool.dense

	for i = shortestPool.size, 1, -1 do
		local hasForbidden = false
		local hasRequired = true
		local entity = dense[i]
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, pool in ipairs(forbidden) do
			if pool.sparse[entityId] then
				hasForbidden = true
				break
			end
		end

		if hasForbidden then
			continue
		end

		for k, pool in ipairs(required) do
			local idx = pool.sparse[entityId]

			if not idx then
				hasRequired = false
				break
			end

			componentPack[k] = pool.objects[idx]
		end

		if hasRequired then
			func(entity, unpack(componentPack))
		end
	end
end

function MultiWithForbidden:eachEntity(func)
	local required = self.required
	local forbidden = self.forbidden

	for _, entity in ipairs(selectShortestPool(required).dense) do
		local hasForbidden = false
		local hasRequired = true
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, pool in ipairs(forbidden) do
			if pool.sparse[entityId] then
				hasForbidden = true
				break
			end
		end

		if hasForbidden then
			continue
		end

		for _, pool in ipairs(required) do
			local idx = pool.sparse[entityId]

			if not idx then
				hasRequired = false
				break
			end
		end

		if hasRequired then
			func(entity)
		end
	end
end

function MultiWithForbidden:mutEachEntity(func)
	local required = self.required
	local forbidden = self.forbidden
	local shortestPool = selectShortestPool(required)
	local dense = shortestPool.dense

	for i = shortestPool.size, 1, -1 do
		local hasForbidden = false
		local hasRequired = true
		local entity = dense[i]
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, pool in ipairs(forbidden) do
			if pool.sparse[entityId] then
				hasForbidden = true
				break
			end
		end

		if hasForbidden then
			continue
		end

		for _, pool in ipairs(required) do
			local idx = pool.sparse[entityId]

			if not idx then
				hasRequired = false
				break
			end
		end

		if hasRequired then
			func(entity)
		end
	end
end

MultiWithForbidden.size = size

function SingleWithForbidden:each(func)
	local objects = self.required[1].objects
	local forbidden = self.forbidden

	for idx, entity in ipairs(self.required[1].dense) do
		local hasForbidden = false
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, pool in ipairs(forbidden) do
			if pool.sparse[entityId] then
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

function SingleWithForbidden:mutEach(func)
	local pool = self.required[1]
	local objects = pool.objects
	local dense = pool.dense
	local forbidden = self.forbidden

	for i = pool.size, 1, -1 do
		local hasForbidden = false
		local entity = dense[i]
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, forbiddenPool in ipairs(forbidden) do
			if forbiddenPool.sparse[entityId] then
				hasForbidden = true
				break
			end
		end

		if hasForbidden then
			continue
		end

		func(entity, objects[i])
	end
end

function SingleWithForbidden:eachEntity(func)
	local forbidden = self.forbidden

	for _, entity in ipairs(self.required[1].dense) do
		local hasForbidden = false
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, pool in ipairs(forbidden) do
			if pool.sparse[entityId] then
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

function SingleWithForbidden:mutEachEntity(func)
	local pool = self.required[1]
	local dense = pool.dense
	local forbidden = self.forbidden

	for i = pool.size, 1, -1 do
		local hasForbidden = false
		local entity = dense[i]
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, forbiddenPool in ipairs(forbidden) do
			if forbiddenPool.sparse[entityId] then
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

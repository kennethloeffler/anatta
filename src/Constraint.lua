local Constants = require(script.Parent.Core).Constants
local View = require(script.Parent.View)
local Observer = require(script.Parent.Observer)

local NONE = Constants.NONE

local Constraint = {}
Constraint.__index = Constraint

local function selectPools(manifest, ...)
	local num = select("#", ...)
	local pools = table.create(num)

	for i = 1, num do
		pools[i] = manifest:getPool(select(i, ...))
	end
end

function Constraint.new(manifest)
	return setmetatable({
		manifest = manifest,
		componentPack = NONE
	}, Constraint)
end

function Constraint:all(...)
	self.required = selectPools(self.manifest, ...)

	return self
end

function Constraint:except(...)
	self.forbidden = selectPools(self.manifest, ...)

	return self
end

function Constraint:updated(...)
	self.changed = selectPools(self.manifest, ...)

	return self
end

function Constraint:view()
	return View.new(self)
end

function Constraint:observer(name)
	return Observer.new(self, name)
end

return Constraint

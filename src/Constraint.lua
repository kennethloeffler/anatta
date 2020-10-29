local Constants = require(script.Parent.Core).Constants
local View = require(script.Parent.View)
local Observer = require(script.Parent.Observer)

local NONE = Constants.NONE

local Constraint = {}
Constraint.__index = Constraint

function Constraint.new(manifest)
	return setmetatable({
		manifest = manifest,
		required = NONE,
		forbidden = NONE,
		changed = NONE,
		componentPack = NONE
	}, Constraint)
end

function Constraint:all(...)
	self.required = self.manifest:getPools(...)

	return self
end

function Constraint:except(...)
	self.forbidden = self.manifest:getPools(...)

	return self
end

function Constraint:updated(...)
	self.changed = self.manifest:getPools(...)

	return self
end

function Constraint:view()
	return View.new(self)
end

function Constraint:observer(name)
	return Observer.new(self, name)
end

return Constraint

local View = require(script.Parent.View)
local Observer = require(script.Parent.Observer)
local Pool = require(script.Parent.Pool)

local NONE = {}

local Constraint = {}
Constraint.__index = Constraint

function Constraint.new(manifest, required, forbidden, changed)
	return setmetatable({
		manifest = manifest,
		required = required or NONE,
		forbidden = forbidden or NONE,
		changed = changed or NONE,

		componentPack = NONE
	}, Constraint)
end

function Constraint:all(...)
	self.required = { ... }

	return self
end

function Constraint:except(...)
	self.forbidden = { ... }

	return self
end

function Constraint:updated(...)
    self.changed = { ... }

    return self
end

function Constraint:view()
	return View.new(self)
end

function Constraint:observer(name)
	return Observer.new(self, name)
end

return Constraint

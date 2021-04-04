local Entity = require(script.Entity)
local t = require(script.Parent.t)
local util = require(script.Parent.util)

local IsSystem = t.interface({
	init = t.callback
})

local Anatta = {}
Anatta.__index = Anatta

function Anatta.define(components)
	return setmetatable({
		_registry = Entity.Registry.new(components),
		_systems = {},
	}, Anatta)
end

function Anatta:loadSystems(container)
	for _, descendant in ipairs(container:GetDescendants()) do
		if
			descendant:IsA("ModuleScript")
			and not descendant.Name:match("%.spec$")
		then
			self:loadSystem(descendant)
		end
	end
end

function Anatta:loadSystem(moduleScript)
	local system = Entity.System.new(self._registry)
	local systemModule = require(moduleScript)

	util.jumpAssert(IsSystem(systemModule))

	self._systems[moduleScript] = system
	systemModule.system = system
	systemModule.registry = self._registry

	systemModule:init()

	return systemModule
end

function Anatta:unloadSystem(moduleScript)
	self._systems[moduleScript]:unload()
end

return Anatta

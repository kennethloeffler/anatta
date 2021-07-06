local Entity = require(script.Entity)
local System = require(script.System)
local t = require(script.Parent.t)
local util = require(script.util)

local Anatta = {}
Anatta.__index = Anatta

function Anatta.new(components)
	return setmetatable({
		_registry = Entity.Registry.new(components),
		_systems = {},
	}, Anatta)
end

function Anatta:loadSystems(container)
	for _, descendant in ipairs(container:GetChildren()) do
		if descendant:IsA("ModuleScript") and not descendant.Name:match("%.spec$") then
			self:loadSystem(descendant)
		end
	end
end

function Anatta:unloadSystems(container)
	for _, descendant in ipairs(container:GetChildren()) do
		if descendant:IsA("ModuleScript") and not descendant.Name:match("%.spec$") then
			self:unloadSystem(descendant)
		end
	end
end

function Anatta:loadSystem(moduleScript, ...)
	local system = System.new(self._registry)
	local systemModule = require(moduleScript)

	util.jumpAssert(t.callback(systemModule))

	self._systems[moduleScript] = system
	systemModule(system, self._registry, ...)

	return systemModule
end

function Anatta:unloadSystem(moduleScript)
	self._systems[moduleScript]:unload()
end

return Anatta

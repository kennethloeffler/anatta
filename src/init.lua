local Entity = require(script.Entity)

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
		end
	end
end

function Anatta:_loadSystem(moduleScript)
	local loadSystem = require(moduleScript)
	local system = Entity.System.new(self._registry)

	self._systems[moduleScript] = system

	return loadSystem(system)
end

function Anatta:_unloadSystem(moduleScript)
	self._systems[moduleScript]:unload()
end

return Anatta

local Dom = require(script.Dom)
local Entity = require(script.Entity)
local System = require(script.System)
local t = require(script.Parent.t)
local Type = require(script.Core.Type)
local util = require(script.util)

local Anatta = {}
Anatta.__index = Anatta

Anatta.Dom = Dom
Anatta.t = Type

function Anatta.new(components)
	return setmetatable({
		registry = Entity.Registry.new(components),
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

function Anatta:unloadAllSystems()
	for _, systemList in pairs(self._systems) do
		for i, system in ipairs(systemList) do
			systemList[i] = nil
			system:unload()
		end
	end
end

function Anatta:loadSystem(moduleScript, ...)
	local system = System.new(self.registry)
	local loadSystem = require(moduleScript)

	warn(("Loaded system %s"):format(moduleScript.Name))
	util.jumpAssert(t.callback(loadSystem))

	if self._systems[moduleScript] == nil then
		self._systems[moduleScript] = { system }
	else
		table.insert(self._systems[moduleScript], system)
	end

	loadSystem(system, self.registry, ...)

	return loadSystem
end

function Anatta:unloadSystem(moduleScript)
	if not self._systems[moduleScript] then
		warn(("Module %s was never loaded"):format(moduleScript.Name))
		return
	end

	for _, system in ipairs(self._systems[moduleScript]) do
		print(system)
		system:unload()
	end
end

return Anatta

local Entity = require(script.Parent.Entity)
local System = require(script.Parent.System)
local t = require(script.Parent.Parent.t)
local util = require(script.Parent.util)

local CheckComponentDefinition = t.strictInterface({
	name = t.string,
	type = t.table,
	meta = t.optional(t.strictInterface({
		plugin = t.strictInterface({
			conversion = t.callback,
			type = t.table,
		}),
	})),
})

local Loader = {}
Loader.__index = Loader

function Loader.new(components)
	return setmetatable({
		registry = Entity.Registry.new(components),
		_systems = {},
	}, Loader)
end

function Loader:loadComponents(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ModuleScript") and not child.Name:match("%.spec$") then
			local definition = require(child)

			util.jumpAssert(CheckComponentDefinition(definition))

			self.registry:define(definition.name, definition.type)
		end
	end
end

function Loader:loadSystems(container, ...)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ModuleScript") and not child.Name:match("%.spec$") then
			self:loadSystem(child, ...)
		end
	end
end

function Loader:unloadAllSystems()
	for _, systemList in pairs(self._systems) do
		for i, system in ipairs(systemList) do
			systemList[i] = nil
			system:unload()
		end
	end
end

function Loader:loadSystem(moduleScript, ...)
	local system = System.new(self.registry)
	local loadSystem = require(moduleScript)

	util.jumpAssert(t.callback(loadSystem))

	if self._systems[moduleScript] == nil then
		self._systems[moduleScript] = { system }
	else
		table.insert(self._systems[moduleScript], system)
	end

	loadSystem(system, ...)

	return loadSystem
end

function Loader:unloadSystem(moduleScript)
	if not self._systems[moduleScript] then
		warn(("Module %s was never loaded"):format(moduleScript.Name))
		return
	end

	for _, system in ipairs(self._systems[moduleScript]) do
		system:unload()
	end
end

return Loader

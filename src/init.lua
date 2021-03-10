local Entity = require(script.Entity)

local detach = Entity.Attachments.detach

local System = {}
System.__index = {}

function System:on(event, callback)
	table.insert(self._connections, event:Connect(callback))
end

function System:match()
	local matcher = Entity.Matcher.new(self._registry)

	table.insert(self._matchers, matcher)

	return matcher
end

function System:getRegistry()
	return self._registry
end

local Anatta = {}
Anatta.__index = Anatta

function Anatta.new(components)
	return setmetatable({
		_registry = Entity.Registry.new(components),
		_systems = {},
	})
end

function Anatta:loadSystems(container)
	for _, descendant in ipairs(container:GetDescendants()) do
		if
			descendant:IsA("ModuleScript")
			and not descendant.Name:match("%.spec$")
		then
			Anatta:_loadSystem(descendant)
		end
	end
end

function Anatta:_loadSystem(moduleScript)
	local loadSystem = require(moduleScript)
	local system = setmetatable({
		_connections = self._connections,
		_matchers = self._matchers,
		_registry = self._registry,
	}, self._registry)

	loadSystem(system)
	self._systems[moduleScript] = system
end

function Anatta:_unloadSystem(moduleScript)
	local system = self._systems[moduleScript]

	for _, connection in ipairs(system._connections) do
		connection:Disconnect()
	end

	for _, matcher in ipairs(system._matchers) do
		detach(matcher.collection)
	end

	self._systems[moduleScript] = nil
end

return {
	define = Anatta.new,
}

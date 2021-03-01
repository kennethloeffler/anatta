local Entity = require(script.Entity)
local Types = require(script.Parent.Core.Types)
local util = require(script.Parent.util)

local Anatta = {}
Anatta.__index = Anatta

function Anatta.new()
	return setmetatable({
		_registry = Entity.Registry.new(),
		_systems = {},
	}, Anatta)
end

function Anatta:defineComponents(definitions)
	for componentName, typeCheck in pairs(definitions) do
		self._registry:define(componentName, typeCheck)
	end
end

function Anatta:loadSystemsFrom(container)
	for _, moduleScript in pairs(container:GetDescendants()) do
		if
			moduleScript:IsA("ModuleScript")
			and not moduleScript.Name:match("%.spec$")
		then
			self:_load(moduleScript)
		end
	end
end

function Anatta:_load(moduleScript)
	local system = require(moduleScript)
	local isPure = system.isPure

	if isPure then
		util.assertAtCallSite(Types.pureSystem(system))
	else
		util.assertAtCallSite(Types.system(system))
	end

	local collection = isPure
		and Entity.ImmutableCollection.new(self._registry, system.collection)
		or Entity.Collection.new(self._registry, system.collection)

	local isImpure = not isPure
	local maybeRegistry = isImpure and self._registry

	local connections = table.create(2)

	if system.onLoaded then
		system.onLoaded(collection, maybeRegistry or nil)
	end

	if system.onAdded then
		table.insert(connections, collection.onAdded:connect(system.onAdded))
	end

	if system.onRemoved then
		table.insert(connections, collection.onRemoved:connect(system.onRemoved))
	end

	self._systems[moduleScript] = {
		collection = collection,
		connections = connections,
		onUnloaded = system.onUnloaded
	}
end

function Anatta:_unload(moduleScript)
	local system = self._systems[moduleScript]

	util.assertAtCallSite(
		system,
		("%s is not loaded"):format(moduleScript:GetFullName())
	)

	local isImpure = not system.isPure
	local maybeRegistry = isImpure and self._registry

	if system.onUnloaded then
		system.onUnloaded(system.collection, maybeRegistry or nil)
	end

	for _, disconnect in ipairs(system.connections) do
		disconnect()
	end

	system.collection:disconnect()
end

return Anatta

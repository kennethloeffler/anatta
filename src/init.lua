local RunService = game:GetService("RunService")

-- Document = component list (entities + data), one per unique component type

-- Schema = all of the component type definitions

-- Collection = the entire entity system (could have multiple of these; for example, one
-- for game objects and one for ui)


local Entity = require(script.Entity)
local Types = require(script.Core.Types)
local t = require(script.t)

local ErrBadCallbackType = "%s must return a function"

local anatta = {}
anatta.__index = anatta

anatta.t = t

function anatta.new()
	local registry = Entity.Registry.new()

	return setmetatable({
		_registry = registry,
		_systemConnections = {},
	}, anatta)
end

function anatta:define(components)
	for name, definition in pairs(components) do
		self._registry:define(name, definition)
	end
end

function anatta:loadSystem(moduleScript)
	local system = require(moduleScript)

	assert(Types.system(system))

	local registry = self._registry
	local connections = {}

	self._systemConnections[moduleScript] = connections

	if system.pure then
		-- a pure system only has access to a reducer and cannot listen to registry
		-- events
		self:_initializeSystem(system, Entity.Reducer.new(registry, {
			required = system.components.required,
			forbidden = system.components.forbidden,
		}))
	else
		-- an impure system has access to the registry and a selector, and is allowed to
		-- listen to registry events
		local selector = Entity.Selector.new(registry, {
			required = system.components.required,
			forbidden = system.components.forbidden,
			updated = system.components.updated,
		})

		if system.onAdded then
			local onAdded = system.onAdded(registry, selector)
			assert(t.callback(onAdded), ErrBadCallbackType:format("onAdded"))

			table.insert(connections, selector:onAdded(system.onAdded))
		end

		if system.onRemoved then
			local onRemoved = system.onRemoved(registry, selector)
			assert(t.callback(onRemoved), ErrBadCallbackType:format("onAdded"))

			table.insert(connections, selector:onRemoved(system.onRemoved))
		end

		table.insert(connections, selector:connect())

		self:_initializeSystem(system, connections, registry, selector)
	end
end

function anatta:unloadSystem(moduleScript)
	local system = require(moduleScript)
	local connections = self._systemConnections[moduleScript]
	assert(connections, ("%s is not loaded"):format(moduleScript:GetFullName()))

	if system.onUnload then
		system.onUnload()
	end

	for _, disconnect in ipairs(connections) do
		if type(disconnect) == "function" then
			disconnect()
		else
			disconnect:Disconnect()
		end
	end
end

function anatta:loadSystemsIn(instance)
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("ModuleScript") and not child.Name:match(".*%.spec") then
			self:loadSystem(child)
		end
	end
end

function anatta:_initializeSystem(system, connections, ...)
	if system.init then
		system.init(...)
	end

	if system.stepped then
		local stepped = system.stepped(...)
		assert(t.callback(stepped), ErrBadCallbackType:format("stepped"))

		table.insert(connections, RunService.Stepped:Connect(stepped))
	end

	if system.heartbeat then
		local stepped = system.heartbeat(...)
		assert(t.callback(stepped), ErrBadCallbackType:format("heartbeat"))

		table.insert(connections, RunService.Heartbeat:Connect(stepped))
	end

	if system.renderStepped then
		local renderStepped = system.renderStepped(...)
		assert(t.callback(renderStepped), ErrBadCallbackType:format("renderStepped"))

		table.insert(connections, RunService.RenderStepped:Connect(renderStepped))
	end
end


return anatta

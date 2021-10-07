local Mapper = require(script.Mapper)
local Reactor = require(script.Reactor)
local Registry = require(script.Registry)

local World = {}
World.__index = World

function World.new()
	return setmetatable({
		registry = Registry.new(),
	}, World)
end

function World:getMapper(query)
	return Mapper.new(self.registry, query)
end

function World:getReactor(query)
	return Reactor.new(self.registry, query)
end

return World

local Manifest = require(script.Parent.Manifest)
local Snapshot = require(script.Parent.Snapshot)
local Identify = require(script.Parent.Parent.core.Identify)

Identify.Flush()

Manifest:DefineComponent("Test1", "table")
Manifest:DefineComponent("Test2", "table")

local TestContainer = {
	[Manifest.Component.Test1] = function(cont, entity, test1)
	end,
	[Manifest.Component.Test2] = function(cont, entity, test2)
	end
}
TestContainer.__index = TestContainer

function TestContainer:Size(size)
	-- could initialize table to correct size with table.create with roblox std
	self.Data = {}
	return size
end

function TestContainer:Entity(entity)
	table.insert(self, entity)
end

function TestContainer.new()
	return setmetatable({}, TestContainer)
end

return function()
	describe("new", function()
		it("should construct a new snapshot instance", function()
			local manifest = Manifest.new()
			local lastDestroyed = 0
			local getNext = function() end
			local snapshot = Snapshot.new(manifest, lastDestroyed, getNext)

			expect(snapshot.Source).to.equal(manifest)
			expect(snapshot.LastDestroyed).to.equal(lastDestroyed)
			expect(snapshot.GetNextDestroyed).to.equal(getNext)

			expect(snapshot.Entities).to.be.a("function")
			expect(snapshot.Destroyed).to.be.a("function")
			expect(snapshot.Components).to.be.a("function")
		end)
	end)

	describe("Entities", function()
	end)

	describe("Destroyed", function()
	end)

	describe("Components", function()
	end)
end

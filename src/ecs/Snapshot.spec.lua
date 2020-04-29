local Manifest = require(script.Parent.Manifest)
local Snapshot = require(script.Parent.Snapshot)

local TestContainer = {}
TestContainer.__index = TestContainer

function TestContainer:Size(size)
end

function TestContainer:Entity(entity)
end

function TestContainer:Component(entity, component)
end

return function()
	describe("new", function()
		-- full coverage!!!!!
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

local Manifest = require(script.Parent.Manifest)
local Snapshot = require(script.Parent.Snapshot)
local Identify = require(script.Parent.Parent.core.Identify)

return function()
	local manifest = Manifest.new()

	local test1 = manifest:Define("test1", "table")
	local test2 = manifest:Define("test2", "table")

	local Container = {
		[test1] = function(container, entity, test1)
		end,
		[test2] = function(container, entity, test2)
		end
	}
	Container.__index = Container

	function Container.new()
		return setmetatable({}, Container)
	end

	function Container:Size()
		self.Data = self.Data or {}
	end

	function Container:Entity(entity)
		table.insert(self.Data, entity)
	end

	local ent1 = manifest:Create()
	local ent2 = manifest:Create()
	local ent3 = manifest:Create()

	manifest:Destroy(manifest:Create())

	describe("new", function()
		it("should construct a new snapshot instance", function()
			local getNext = function() end
			local snapshot = Snapshot.new(manifest, manifest.Head, getNext)

			expect(snapshot.Source).to.equal(manifest)
			expect(snapshot.LastDestroyed).to.equal(manifest.Head)
			expect(snapshot.GetNextDestroyed).to.equal(getNext)

			expect(snapshot.Entities).to.be.a("function")
			expect(snapshot.Destroyed).to.be.a("function")
			expect(snapshot.Components).to.be.a("function")
		end)
	end)

	describe("Entities", function()
		local snapshot = manifest:Snapshot()

		
	end)

	describe("Destroyed", function()
	end)

	describe("Components", function()
	end)
end

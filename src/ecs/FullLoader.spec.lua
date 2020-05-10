local Manifest = require(script.Parent.Manifest)

return function()
	local source = Manifest.new()
	local destination = Manifest.new()
	local loader = destination:Loader()
	local cont = {}

	local ents = {}
	local destEnts = {}

	source:Define("test1", "table")
	source:Define("test2", "table")

	-- these will end up having the same respective component ids, but
	-- this test does not rely on that fact
	destination:Define("test1", "table")
	destination:Define("test2", "table")

	for i = 1, 32 do
		local ent = source:Create()

		ents[ent] = true
		destEnts[source:Create()] = true

		if i % 4 == 0 then
			source:Assign(ent, source.Component.test1, {})
			source:Assign(ent, source.Component.test2, {})
		end
	end

	for entity in pairs(destEnts) do
		source:Destroy(entity)
	end

	source:Snapshot():Entities(cont):Destroyed(cont):Components(cont, source.Component.test1, source.Component.test2)
	loader:Entities(cont):Destroyed(cont):Components(cont, destination.Component.test1, destination.Component.test2)

	describe("new", function()
		it("should construct a new loader instance", function()
			expect(loader.Destination).to.equal(destination)

			expect(loader.Entities).to.be.a("function")
			expect(loader.Destroyed).to.be.a("function")
			expect(loader.Components).to.be.a("function")
		end)
	end)

	describe("Entities", function()
		it("should deserialize all of the entities", function()
		end)
	end)

	describe("Destroyed", function()
		it("should deserialize all of the destroyed entities", function()
		end)
	end)

	describe("Components", function()
		it("should deserialize the component", function()
		end)
	end)

	describe("Dead", function()
	end)
end

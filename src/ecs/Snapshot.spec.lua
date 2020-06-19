local Manifest = require(script.Parent.Manifest)
local Snapshot = require(script.Parent.Snapshot)

return function()
	local manifest = Manifest.new()

	local test1 = manifest:define("table", "test1")
	local test2 = manifest:define("table", "test2")

	local ents = {}
	local destEnts = {}
	local comps = { {}, {} }

	for i = 1, 32 do
		local ent = manifest:create()

		if i % 4 == 0 then
			comps[test1][ent] = manifest:assign(ent, manifest.component:named("test1"), {})
			comps[test2][ent] = manifest:assign(ent, manifest.component:named("test2"), {})
		end

		ents[ent] = true
	end

	for entity in pairs(destEnts) do
		manifest:destroy(entity)
	end

	describe("new", function()
		it("should construct a new snapshot instance", function()
			local snapshot = Snapshot.new(manifest)

			expect(snapshot.source).to.equal(manifest)

			expect(snapshot.entities).to.be.a("function")
			expect(snapshot.components).to.be.a("function")
		end)
	end)

	describe("entities", function()
		local container = {}

		Snapshot.new(manifest):entities(container)

		it("should serialize all of the entities", function()
			for i, entity in ipairs(manifest.entities) do
				expect(container[1][i]).to.be.ok()
				expect(container[1][i]).to.equal(entity)
			end
		end)
	end)

	describe("components", function()
		local container = {}

		Snapshot.new(manifest):components(container, test1, test2)

		it("should serialize components with their entities", function()
			local idx = 1

			for componentId = 1, 2 do
				for i, entity in ipairs(manifest:_getPool(componentId).internal) do
					local component = comps[componentId][entity]
					local serializedComponent = container[idx + 1][i]

					expect(component).to.be.ok()
					expect(component).to.equal(serializedComponent)
				end

				idx = idx + 2
			end
		end)
	end)
end

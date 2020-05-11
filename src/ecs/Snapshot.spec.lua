local Manifest = require(script.Parent.Manifest)
local Constants = require(script.Parent.Parent.Constants)

local ENTITYID_MASK = Constants.ENTITYID_MASK
local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH

return function()
	local manifest = Manifest.new()

	local test1 = manifest:define("test1", "table")
	local test2 = manifest:define("test2", "table")

	local ents = {}
	local destEnts = {}
	local comps = { {}, {} }

	for i = 1, 32 do
		local ent = manifest:create()

		if i % 4 == 0 then
			comps[test1][ent] = manifest:assign(ent, manifest.component.test1, {})
			comps[test2][ent] = manifest:assign(ent, manifest.component.test2, {})
		end

		ents[ent] = true
		destEnts[manifest:create()] = true
	end

	for entity in pairs(destEnts) do
		manifest:destroy(entity)
	end

	describe("new", function()
		it("should construct a new snapshot instance", function()
			local snapshot = manifest:snapshot()

			expect(snapshot.source).to.equal(manifest)

			expect(snapshot.entities).to.be.a("function")
			expect(snapshot.destroyed).to.be.a("function")
			expect(snapshot.components).to.be.a("function")
		end)
	end)

	describe("Entities", function()
		local snapshot = manifest:snapshot()
		local container = {}

		snapshot:entities(container)

		it("should serialize all of the entities alive", function()
			for _, entity in ipairs(container[1]) do
				expect(ents[entity]).to.be.ok()
			end
		end)
	end)

	describe("Destroyed", function()
		local snapshot = manifest:snapshot()
		local container = {}

		snapshot:destroyed(container)

		it("should serialize all of the destroyed entities destroyed", function()
			   for _, entity in ipairs(container[1]) do
				local entityId = bit32.band(entity, ENTITYID_MASK)
				local version = bit32.rshift(entity, ENTITYID_WIDTH)

				-- entityId will be equal to the identifier in destEnts
				-- i.e. the versions of the initial idenitifers are equal to 0
				expect(destEnts[entityId]).to.be.ok()
				expect(version).to.equal(1)
			end
		end)
	end)

	describe("Components", function()
		local snapshot = manifest:snapshot()
		local container = {}

		snapshot:components(container, test1, test2)

		it("should serialize components with their entities", function()
			local idx = 1

			for componentId = 1, 2 do
				for i, entity in ipairs(container[idx]) do
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

local Manifest = require(script.Parent.Manifest)

return function()
	local source = Manifest.new()
	local destination = Manifest.new()

	source:define("test1", "table")
	source:define("test2", "table")

	-- these will end up having the same respective component ids, but
	-- this test does not rely on that fact
	destination:define("test1", "table")
	destination:define("test2", "table")

	local ents = {}
	local destEnts = {}

	for i = 1, 32 do
		local ent = source:create()

		ents[ent] = true
		destEnts[source:create()] = true

		if i % 4 == 0 then
			source:assign(ent, source.component.test1, {})
			source:assign(ent, source.component.test2, {})
		end
	end

	for entity in pairs(destEnts) do
		source:destroy(entity)
	end

	local cont = {}

	source:snapshot()
		:entities(cont)
		:destroyed(cont)
		:components(cont, source.component.test1, source.component.test2)

	destination:loader()
		:entities(cont)
		:destroyed(cont)
		:components(cont, destination.component.test1, destination.component.test2)

	describe("new", function()
		it("should construct a new loader instance", function()
			local m = Manifest.new()
			local l = m:loader()

			expect(l.destination).to.equal(m)

			expect(l.entities).to.be.a("function")
			expect(l.destroyed).to.be.a("function")
			expect(l.components).to.be.a("function")
		end)
	end)

	describe("entities", function()
		it("should deserialize all of the entities", function()
			destination:forEach(function(entity)
				expect(ents[entity]).to.be.ok()
			end)
		end)
	end)

	describe("destroyed", function()
		it("should deserialize all of the destroyed entities", function()
			for entity in pairs(destEnts) do
				expect(destination:valid(entity)).to.equal(false)
			end
		end)
	end)

	describe("components", function()
		it("should deserialize the components", function()
			local test1 = destination.component.test1
			local test2 = destination.component.test2
			local test1Pool = destination:_getPool(test1)
			local test2Pool = destination:_getPool(test2)

			for _, entity in ipairs(test1Pool.internal) do
				expect(destination:has(entity, test1)).to.equal(true)
				expect(destination:get(entity, test1)).to.equal(source:get(entity, source.component.test1))
			end

			for _, entity in ipairs(test2Pool.internal) do
				expect(destination:has(entity, test2)).to.equal(true)
				expect(destination:get(entity, test2)).to.equal(source:get(entity, source.component.test2))
			end
		end)
	end)

	describe("stubs", function()
		it("should destroy all the stub entities in the destination manifest", function()
			local c = {}
			local dest = Manifest.new()

			source:snapshot()
				:entities(c)

			dest:loader()
				:entities(c)
				:stubs()

			dest:forEach(function(entity)
				expect(destEnts[entity]).to.never.be.ok()
			end)
		end)
	end)
end

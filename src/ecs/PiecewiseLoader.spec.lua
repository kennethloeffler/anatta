local Manifest = require(script.Parent.Manifest)
local Snapshot = require(script.Parent.Snapshot)
local PiecewiseLoader = require(script.Parent.PiecewiseLoader)

return function()
	local source = Manifest.new()
	local destination = Manifest.new()
	local loader = PiecewiseLoader.new(destination)

	source:define("table", "test1")
	source:define("table", "test2")

	-- these will end up having the same respective component ids, but
	-- this test does not rely on that fact
	destination:define("table", "test1")
	destination:define("table", "test2")

	local entities = {}
	local componentEntities = {}
	local destroyedEntities = {}

	for i = 1, 32 do
		local entity = source:create()

		entities[entity] = true
		destroyedEntities[source:create()] = true

		if i % 4 == 0 then
			source:assign(entity, source.component:named("test1"), { entity = entity })
			source:assign(entity, source.component:named("test2"), { entityList = { entity }})
			componentEntities[entity] = true
		end
	end

	for entity in pairs(destroyedEntities) do
		source:destroy(entity)
	end

	local e1 = source:create()
	local e2 = source:create()

	describe("new", function()
		it("should construct a new loader instance attached to the destination manifest", function()
			expect(loader.destination).to.equal(destination)
			expect(getmetatable(loader)).to.equal(PiecewiseLoader)
		end)
	end)

	describe("entity", function()
		local e = source:create()

		loader:entity(e)

		local mirrorEntity = loader.mirrored[e]

		it("should mirror a single given entity", function()
			expect(mirrorEntity).to.be.ok()
		end)

		it("should create a destroyed mirror entity", function()
			expect(destination:valid(mirrorEntity)).to.equal(false)
			expect(loader.dirty[e]).to.equal(true)
		end)
	end)

	describe("component", function()
		it("should mirror a single given component on a given entity", function()
			local component = {}

			loader:component(e2, destination.component:named("test1"), component)

			local mirrorEntity = loader.mirrored[e2]

			expect(mirrorEntity).to.be.ok()
			expect(destination:valid(mirrorEntity)).to.equal(true)
			expect(destination:has(mirrorEntity, destination.component:named("test1")))
				.to.equal(true)
			expect(destination:get(mirrorEntity, destination.component:named("test1")))
				.to.equal(component)
		end)

		it("should mark the remote entity dirty", function()
			expect(loader.dirty[e2]).to.equal(true)
		end)

		it("should replace entities that are members of a component with ther mirrors", function()
			local entityList = { e2, e1 }

			loader:entity(e1)

			loader:component(
				e2,
				destination.component:named("test1"),
				{ entity = e1, entityList = { e2, e1 } },
				{ "entity", "entityList" })

			local mirrorEntity = loader.mirrored[e2]
			local mirrorComponent = destination:get(mirrorEntity, destination.component:named("test1"))

			expect(mirrorComponent.entity).to.equal(loader.mirrored[e1])

			for i, entity in ipairs(entityList) do
				expect(loader.mirrored[entity]).to.equal(mirrorComponent.entityList[i])
			end
		end)
	end)

	describe("entities", function()
		it("should mirror the given entities", function()
			local cont = {}

			Snapshot.new(source):entities(cont)
			loader:entities(cont)

			for _, entity in ipairs(cont[1]) do
				expect(loader.mirrored[entity]).to.be.ok()
				expect(loader.dirty[entity]).to.equal(true)
			end
		end)
	end)

	describe("components", function()
		local cont = {}

		Snapshot.new(source):components(
			cont,
			source.component:named("test1"),
			source.component:named("test2"))

		loader:components(
			cont,
			{
				destination.component:named("test1"),
				destination.component:named("test2")
			},
			{
				[destination.component:named("test1")] = { "entity" },
				[destination.component:named("test2")] = { "entityList" }
			})

		it("should mirror the given components and their entities", function()
			local mirrorEntity

			for entity in pairs(componentEntities) do
				mirrorEntity = loader.mirrored[entity]

				expect(destination:valid(mirrorEntity)).to.equal(true)
				expect(destination:has(mirrorEntity, destination.component:named("test1"))).to.equal(true)
				expect(destination:get(mirrorEntity, destination.component:named("test1")))
					.to.equal(source:get(entity, source.component:named("test1")))

				expect(destination:has(mirrorEntity, destination.component:named("test2"))).to.equal(true)
				expect(destination:get(mirrorEntity, destination.component:named("test2")))
					.to.equal(source:get(entity, source.component:named("test2")))
			end
		end)

		it("should replace entities that are members of a component with ther mirrors", function()
			local mirrorEntity

			for entity in pairs(componentEntities) do
				mirrorEntity = loader.mirrored[entity]

				local comp1 = destination:get(mirrorEntity, destination.component:named("test1"))

				expect(comp1.entity)
					.to.equal(mirrorEntity)

				expect(destination:get(mirrorEntity, destination.component:named("test2")).entityList[1])
					.to.equal(mirrorEntity)
			end
		end)
	end)

	describe("stubs", function()
		local cont = {}

		Snapshot.new(source):entities(cont)
		loader:entities(cont)

		it("should remove all entities that don't have any components", function()
			loader:stubs()

			destination:forEach(function(entity)
				expect(destination:stub(entity)).to.equal(false)
			end)
		end)
	end)

	describe("clean", function()
		local cont = {}

		Snapshot.new(source):entities(cont)
		loader:entities(cont)

		it("should mark mirrored entities as clean after one call", function()
			loader:clean()

			for _, dirty in pairs(loader.dirty) do
				expect(dirty).to.equal(false)
			end
		end)

		it("should destroy mirrored entities marked as clean after two successive calls", function()
			loader:entities(cont)

			loader:clean()
			loader:clean()

			expect(next(loader.dirty)).to.never.be.ok()
			expect(next(loader.mirrored)).to.never.be.ok()

			expect(destination:numEntities()).to.equal(0)
		end)
	end)
end

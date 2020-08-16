local Constraint = require(script.Parent.Constraint)
local Manifest = require(script.Parent.Manifest)
local Observer = require(script.Parent.Observer)

return function()
	describe("observer", function()
		beforeEach(function(context)
			local manifest = Manifest.new()

			context.manifest = manifest

			context.comp1 = manifest:define(nil, "test1")
			context.comp2 = manifest:define(nil, "test2")
			context.comp3 = manifest:define(nil, "test3")
			context.comp4 = manifest:define(nil, "test4")

			context.obsAll = Constraint.new(manifest, {context.comp1, context.comp2}):observer()
			context.obsAllExcept = Constraint.new(
				manifest,
				{context.comp1, context.comp2},
				{context.comp3, context.comp4}):observer()
			context.obsUpdated = Constraint.new(
				manifest,
				nil,
				nil,
				{context.comp1, context.comp2}):observer()
		end)

		describe("all", function()
			it("should capture entities with all required components", function(context)
				local entity = context.manifest:create()

				context.manifest:add(entity, context.comp1)
				context.manifest:add(entity, context.comp2)

				expect(context.manifest:has(entity, context.obsAll)).to.equal(true)
			end)

			it("should cull entities that lose any required components", function(context)
				local entity = context.manifest:create()

				context.manifest:add(entity, context.comp1)
				context.manifest:add(entity, context.comp2)

				context.manifest:remove(entity, context.comp1)
				expect(context.manifest:has(entity, context.obsAll)).to.equal(false)
			end)
		end)

		describe("except", function()
			it("should reject entities that have any forbidden components", function(context)
				local entity = context.manifest:create()

				context.manifest:add(entity, context.comp3)

				context.manifest:add(entity, context.comp1)
				context.manifest:add(entity, context.comp2)

				expect(context.manifest:has(entity, context.obsAllExcept)).to.equal(false)
			end)

			it("should cull entities that gain any forbidden components", function(context)
				local entity = context.manifest:create()

				context.manifest:add(entity, context.comp1)
				context.manifest:add(entity, context.comp2)
				expect(context.manifest:has(entity, context.obsAllExcept)).to.equal(true)

				context.manifest:add(entity, context.comp4)
				expect(context.manifest:has(entity, context.obsAllExcept)).to.equal(false)
			end)
		end)

		describe("updated", function()
			it("should capture entities for which the given components have been updated", function(context)
				local e1 = context.manifest:create()
				local e2 = context.manifest:create()

				context.manifest:add(e1, context.comp1)
				context.manifest:add(e2, context.comp1)
				context.manifest:add(e1, context.comp2)
				context.manifest:add(e2, context.comp2)

				context.manifest:replace(e1, context.comp1)
				expect(context.manifest:has(e1, context.obsUpdated)).to.equal(false)

				context.manifest:replace(e1, context.comp2)
				expect(context.manifest:has(e1, context.obsUpdated)).to.equal(true)

				context.manifest:replace(e2, context.comp1)
				expect(context.manifest:has(e2, context.obsUpdated)).to.equal(false)

				context.manifest:replace(e2, context.comp2)
				expect(context.manifest:has(e2, context.obsUpdated)).to.equal(true)
			end)

			it("should cull entities which are destroyed after having been updated", function(context)
				local entity = context.manifest:create()

				context.manifest:add(entity, context.comp1)
				context.manifest:replace(entity, context.comp1)
				context.manifest:add(entity, context.comp2)
				context.manifest:replace(entity, context.comp2)
				expect(context.manifest:has(entity, context.obsUpdated)).to.equal(true)

				context.manifest:remove(entity, context.comp1)
				expect(context.manifest:has(entity, context.obsUpdated)).to.equal(false)
			end)
		end)
	end)
end

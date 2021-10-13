"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[435],{12157:function(e){e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Creates and returns a blank, empty registry.","params":[],"returns":[{"desc":"","lua_type":"Registry"}],"function_type":"static","ignore":true,"source":{"line":70,"path":"lib/src/World/Registry.lua"}},{"name":"getId","desc":"Returns an integer equal to the first `ENTITYID_WIDTH` bits of the\\nentity. The equality\\n\\n```lua\\nregistry._entities[id] == entity\\n```\\n\\ngenerally holds if the entity is valid.","params":[{"name":"entity","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"number"}],"function_type":"static","private":true,"source":{"line":93,"path":"lib/src/World/Registry.lua"}},{"name":"getVersion","desc":"Returns an integer equal to the last `32 - ENTITYID_WIDTH` bits of the\\nentity.","params":[{"name":"entity","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"number"}],"function_type":"static","private":true,"source":{"line":105,"path":"lib/src/World/Registry.lua"}},{"name":"fromRegistry","desc":"Creates a shallow copy of an existing registry.\\n\\nBecause this function fires the added signal for every copied component, it\\nis equivalent to adding each component to the new registry with\\n[`addComponent`](#addComponent).\\n\\n#### Usage:\\n```lua\\nlocal entity1 = registry:createEntity()\\nlocal health1 = registry:addComponent(entity1, Health, 100)\\nlocal inventory1 = registry:addComponent(entity1, Inventory, { \\"Beans\\" })\\n\\nlocal entity2 = registry:createEntity()\\nlocal health2 = registry:addComponent(entity1, Health, 250)\\nlocal inventory2 = registry:addComponent(entity2, Inventory, { \\"Magic Beans\\", \\"Bass Guitar\\" })\\n\\nlocal copied = Registry.fromRegistry(registry)\\n\\n-- we now have an exact copy of the original registry\\nassert(copied:entityIsValid(entity1) and copied:entityIsValid(entity2))\\n\\nlocal copiedHealth1, copiedInventory1 = registry:getComponents(entity1, Health, Inventory)\\nlocal copiedHealth2, copiedInventory2 = registry:getComponents(entity1, Health, Inventory)\\n\\nassert(copiedHealth1 == health1 and copiedInventory1 == inventory1)\\nassert(copiedHealth2 == health2 and copiedInventory2 == inventory2)\\n```","params":[{"name":"original","desc":"","lua_type":"Registry"}],"returns":[{"desc":"","lua_type":"Registry"}],"function_type":"static","ignore":true,"source":{"line":142,"path":"lib/src/World/Registry.lua"}},{"name":"defineComponent","desc":"Defines a new component type for the registry using the given\\n[`ComponentDefinition`](/api/Anatta#ComponentDefinition).\\n\\n#### Usage:\\n```lua\\nlocal Health = registry:defineComponent({\\n\\tname = \\"Health\\",\\n\\ttype = t.number\\n})\\n\\nregistry:addComponent(registry:createEntity(), Health, 100)\\n```","params":[{"name":"definition","desc":"","lua_type":"ComponentDefinition"}],"returns":[],"function_type":"method","errors":[{"lua_type":"\\"there is already a component type named %s\\"","desc":"The name is already being used."}],"private":true,"source":{"line":213,"path":"lib/src/World/Registry.lua"}},{"name":"createEntity","desc":"Creates and returns a unique identifier that represents a game object.\\n\\n#### Usage:\\n```lua\\nlocal entity = registry:createEntity()\\nassert(entity == 1)\\n\\nentity = registry:createEntity()\\nassert(entity == 2)\\n\\nentity = registry:createEntity()\\nassert(entity == 3)\\n```","params":[],"returns":[{"desc":"","lua_type":"number"}],"function_type":"method","source":{"line":250,"path":"lib/src/World/Registry.lua"}},{"name":"createEntityFrom","desc":"Returns an entity equal to the given entity.\\n\\n#### Usage:\\n```lua\\nlocal entity1 = registry:createEntity()\\nregistry:destroyEntity(entity1)\\nassert(registry:createEntityFrom(entity1) == entity1)\\n\\n-- if entity with the same ID already exists, the existing entity is destroyed first\\nlocal entity2 = registry:createEntity()\\nregistry:addComponent(entity2, PrettyFly)\\n\\nentity2 = registry:createEntityFrom(entity2)\\nassert(registry:entityHas(entity2, PrettyFly) == false)\\n```","params":[{"name":"entity","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"number"}],"function_type":"method","private":true,"source":{"line":295,"path":"lib/src/World/Registry.lua"}},{"name":"destroyEntity","desc":"Removes all of an entity\'s components and frees its ID.\\n\\n#### Usage:\\n```lua\\nlocal entity = registry:create()\\n\\nregistry:destroyEntity(entity)\\n\\n-- the entity is no longer valid and functions like getComponent or addComponent will throw\\nassert(registry:entityIsValid(entity) == false)\\n```","params":[{"name":"entity","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."}],"source":{"line":373,"path":"lib/src/World/Registry.lua"}},{"name":"entityIsValid","desc":"Returns `true` if the entity exists. Otherwise, returns `false`.\\n\\n#### Usage:\\n```lua\\nassert(registry:entityIsValid(0) == false)\\n\\nlocal entity = registry:createEntity()\\n\\nassert(registry:entityIsValid(entity) == true)\\n\\nregistry:destroyEntity(entity)\\n\\nassert(registry:entityIsValid(entity) == false)\\n```","params":[{"name":"entity","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","source":{"line":416,"path":"lib/src/World/Registry.lua"}},{"name":"entityIsOrphaned","desc":"Returns `true` if the entity has no components. Otherwise, returns `false`.\\n\\n#### Usage\\n```lua\\nlocal entity = registry:createEntity()\\n\\nassert(self:entityIsOrphaned(entity) == true)\\n\\nregistry:addComponent(entity, Car, {\\n\\tmodel = game.ReplicatedStorage.Car:Clone(),\\n\\tcolor = \\"Red\\",\\n})\\n\\nassert(registry:entityIsOrphaned(entity) == false)\\n```","params":[{"name":"entity","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."}],"source":{"line":446,"path":"lib/src/World/Registry.lua"}},{"name":"visitComponents","desc":"Passes all the component names defined on the registry to the given callback. The\\niteration continues until the callback returns `nil`.\\n\\nIf an entity is given, passes only the components that the entity has.","params":[{"name":"callback","desc":"","lua_type":"(definition: ComponentDefinition) -> boolean"},{"name":"entity","desc":"","lua_type":"number?"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."}],"source":{"line":472,"path":"lib/src/World/Registry.lua"}},{"name":"entityHas","desc":"Returns `true` if the entity all of the given components. Otherwise, returns `false`.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"...","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."}],"source":{"line":508,"path":"lib/src/World/Registry.lua"}},{"name":"entityHasAny","desc":"Returns `true` if the entity has any of the given components. Otherwise, returns\\n`false`.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"...","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."}],"source":{"line":537,"path":"lib/src/World/Registry.lua"}},{"name":"getComponent","desc":"Returns the component of the given type on the entity.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"definition","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"any"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."}],"source":{"line":565,"path":"lib/src/World/Registry.lua"}},{"name":"getComponents","desc":"Returns all of the given components on the entity.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"output","desc":"","lua_type":"table"},{"name":"...","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"...any"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."}],"source":{"line":587,"path":"lib/src/World/Registry.lua"}},{"name":"addComponent","desc":"Adds a component to the entity and returns the component.\\n\\n:::info\\nAn entity can only have one component of each type at a time.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"definition","desc":"","lua_type":"ComponentDefinition"},{"name":"component","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"any"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."},{"lua_type":"\\"entity %d already has a %s\\"","desc":"The entity already has that component."},{"lua_type":"Failed type check","desc":"The given component has the wrong type."}],"source":{"line":611,"path":"lib/src/World/Registry.lua"}},{"name":"withComponents","desc":"Adds the given components to the entity and returns the entity.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"components","desc":"","lua_type":"{[ComponentDefinition]: any}"}],"returns":[{"desc":"","lua_type":"number"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."},{"lua_type":"\\"entity %d already has a %s\\"","desc":"The entity already has that component."},{"lua_type":"Failed type check","desc":"The given component has the wrong type."}],"source":{"line":639,"path":"lib/src/World/Registry.lua"}},{"name":"tryAddComponent","desc":"If the entity does not have the component, adds and returns the component. Otherwise,\\nreturns `nil`.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"definition","desc":"","lua_type":"ComponentDefinition"},{"name":"component","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"any"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."},{"lua_type":"Failed type check","desc":"The given component has the wrong type."}],"source":{"line":660,"path":"lib/src/World/Registry.lua"}},{"name":"getOrAddComponent","desc":"If the entity has the component, returns the component. Otherwise adds the component\\nto the entity and returns the component.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"definition","desc":"","lua_type":"ComponentDefinition"},{"name":"component","desc":"","lua_type":"any"}],"returns":[],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."},{"lua_type":"Failed type check","desc":"The given component has the wrong type."}],"source":{"line":690,"path":"lib/src/World/Registry.lua"}},{"name":"replaceComponent","desc":"Replaces the given component on the entity and returns the new component.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"definition","desc":"","lua_type":"ComponentDefinition"},{"name":"component","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"any"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."},{"lua_type":"Failed type check","desc":"The given component has the wrong type."},{"lua_type":"\\"entity %d does not have a %s\\"","desc":"The entity is expected to have this component."}],"source":{"line":724,"path":"lib/src/World/Registry.lua"}},{"name":"addOrReplaceComponent","desc":"If the entity has the component, replaces it with the given component and returns the\\nnew component. Otherwise, adds the component to the entity and returns the new\\ncomponent.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"definition","desc":"","lua_type":"ComponentDefinition"},{"name":"component","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"any"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."},{"lua_type":"Failed type check","desc":"The given component has the wrong type."}],"source":{"line":754,"path":"lib/src/World/Registry.lua"}},{"name":"removeComponent","desc":"Removes the component from the entity.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"definition","desc":"","lua_type":"ComponentDefinition"}],"returns":[],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."},{"lua_type":"\\"entity %d does not have a %s\\"","desc":"The entity is expected to have this component."}],"source":{"line":787,"path":"lib/src/World/Registry.lua"}},{"name":"tryRemoveComponent","desc":"If the entity has the component, removes it and returns `true`. Otherwise, returns\\n`false`.","params":[{"name":"entity","desc":"","lua_type":"number"},{"name":"definition","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","errors":[{"lua_type":"\\"entity %d does not exist or has been destroyed\\"","desc":"The entity is invalid."},{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."}],"source":{"line":812,"path":"lib/src/World/Registry.lua"}},{"name":"countEntities","desc":"Returns the total number of entities currently in use by the registry.","params":[],"returns":[{"desc":"","lua_type":"number"}],"function_type":"method","source":{"line":833,"path":"lib/src/World/Registry.lua"}},{"name":"countComponents","desc":"Returns the total number of entities with the given component.","params":[{"name":"definition","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"number"}],"function_type":"method","errors":[{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."}],"source":{"line":853,"path":"lib/src/World/Registry.lua"}},{"name":"each","desc":"Passes each entity currently in use by the registry to the given callback.","params":[{"name":"callback","desc":"","lua_type":"(entity: number) -> ()"}],"returns":[],"function_type":"method","source":{"line":868,"path":"lib/src/World/Registry.lua"}},{"name":"isComponentDefined","desc":"Returns `true` if the registry has a component type with the given name. Otherwise,\\nreturns `false`.","params":[{"name":"definition","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","source":{"line":889,"path":"lib/src/World/Registry.lua"}},{"name":"getPools","desc":"Returns a list of the `Pool`s used to manage the given components.","params":[{"name":"definitions","desc":"","lua_type":"{string}"}],"returns":[{"desc":"","lua_type":"{Pool}"}],"function_type":"method","errors":[{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."}],"private":true,"source":{"line":902,"path":"lib/src/World/Registry.lua"}},{"name":"getPool","desc":"Returns the `Pool` containing the given components.","params":[{"name":"definition","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"Pool"}],"function_type":"method","errors":[{"lua_type":"\'the component type \\"%s\\" is not defined for this registry\'","desc":"No component matches that definition."}],"private":true,"source":{"line":927,"path":"lib/src/World/Registry.lua"}}],"properties":[{"name":"_entities","desc":"The list of all entities. Some of them may be destroyed. This property is used to\\ndetermine if any given entity exists or has been destroyed.","lua_type":"{[number]: number}","private":true,"readonly":true,"source":{"line":40,"path":"lib/src/World/Registry.lua"}},{"name":"_pools","desc":"A dictionary mapping component type names to the pools managing instances of the\\ncomponents.","lua_type":"{[ComponentDefinition]: Pool}","private":true,"readonly":true,"source":{"line":47,"path":"lib/src/World/Registry.lua"}},{"name":"_nextRecyclableEntityId","desc":"The next ID to use when creating a new entity. When this property is equal to zero, it\\nmeans there are no IDs available to recycle.","lua_type":"number","private":true,"readonly":true,"source":{"line":54,"path":"lib/src/World/Registry.lua"}},{"name":"_size","desc":"The total number of entities contained in [`_entities`](#_entities).","lua_type":"number","private":true,"readonly":true,"source":{"line":60,"path":"lib/src/World/Registry.lua"}}],"types":[],"name":"Registry","desc":"A `Registry` manages and provides unscoped access to entities and their components. It\\nprovides methods to create and destroy entities and to add, remove, get, or update\\ncomponents.\\n\\nYou can get a `Registry` from a [`World`](/api/World).","source":{"line":9,"path":"lib/src/World/Registry.lua"}}')}}]);
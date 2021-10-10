"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[4],{77799:function(e){e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Creates a new `World` containing an empty [`Registry`](/api/Registry) and calls\\n[`Registry:defineComponent`](/api/Registry#defineComponent) for each\\n[`ComponentDefinition`](/api/Anatta#ComponentDefinition) in the given list.","params":[{"name":"definitions","desc":"","lua_type":"{ComponentDefinition}"}],"returns":[{"desc":"","lua_type":"World"}],"function_type":"static","ignore":true,"source":{"line":96,"path":"lib/src/World/init.lua"}},{"name":"getMapper","desc":"Creates a new [`Mapper`](/api/Mapper) given a [`Query`](#Query).","params":[{"name":"query","desc":"","lua_type":"Query"}],"returns":[{"desc":"","lua_type":"Mapper"}],"function_type":"method","errors":[{"lua_type":"\\"mappers cannot track updates to components; use a Reactor instead\\"","desc":"Reactors can track updates. Mappers can\'t."},{"lua_type":"\\"mappers need at least one component type named in withAll\\"","desc":"There were no components named in withAll."},{"lua_type":"\\"invalid component identifier: %s\\"","desc":"No component goes by that name."}],"source":{"line":123,"path":"lib/src/World/init.lua"}},{"name":"getReactor","desc":"Creates a new [`Reactor`](/api/Reactor) given a [`Query`](#Query).","params":[{"name":"query","desc":"","lua_type":"Query"}],"returns":[{"desc":"","lua_type":"Reactor"}],"function_type":"method","errors":[{"lua_type":"\\"reactors need at least one component type named in withAll, withUpdated, or withAny\\"","desc":"Reactors need components to query."},{"lua_type":"\\"reactors can only track up to 32 updated component types\\"","desc":"More than 32 components were named in withUpdated."},{"lua_type":"\\"invalid component identifier: %s\\"","desc":"No component goes by that name."}],"source":{"line":152,"path":"lib/src/World/init.lua"}}],"properties":[{"name":"registry","desc":"Provides direct, unscoped access to a `World`\'s [`Registry`](/api/Registry).","lua_type":"Registry","source":{"line":14,"path":"lib/src/World/init.lua"}},{"name":"components","desc":"A dictionary mapping component names to component definitions. Intended to be used for importing\\ncomponent definitions as follows:\\n```lua\\n-- Assuming we\'ve already defined the World elsewhere with a component called \\"Money\\"\\nlocal world = Anatta:getWorld(\\"MyCoolWorld\\")\\nlocal registry = world.registry\\n\\nlocal Money = world.components.Money\\n\\nregistry:addComponent(registry:create(), Money, 5000)\\n```","lua_type":"{[string]: ComponentDefinition}","source":{"line":86,"path":"lib/src/World/init.lua"}}],"types":[{"name":"Query","desc":"A `Query` represents a set of entities to retrieve from a\\n[`Registry`](/api/Registry). A `Query` can be finalized by passing it to\\n[`World:getReactor`](#getReactor) or [`World:getMapper`](#getMapper).\\n\\nThe fields of a `Query` determine which entities are yielded. Each field is an\\noptional list of component names that corresponds to one of the following rules:\\n\\n### `Query.withAll`\\nAn entity must have all of these components.\\n\\n### `Query.withUpdated`\\nAn entity must have an updated copy of all of these components.\\n\\n:::warning\\nA [`Mapper`](/api/Mapper) cannot track updates to\\ncomponents. [`World:getMapper`](#getMapper) throws an error when this field is\\nincluded.\\n:::\\n\\n### `Query.withAny`\\nAn entity may have any or none of these components.\\n\\n### `Query.without`\\nAn entity must not have any of these components.\\n\\nMethods like [`Reactor:withAttachments`](/api/Reactor#withAttachments) and\\n[`Mapper:each`](/api/Mapper#each) take callbacks that are passed an entity and its\\ncomponents. Such callbacks receive an entity as their first argument, followed in\\norder by the entity\'s components from `withAll`, then the components from\\n`withUpdated`, and finally the components from `withAny`.","fields":[{"name":"withAll","lua_type":"{ComponentDefinition}?","desc":""},{"name":"withUpdated","lua_type":"{ComponentDefinition}?","desc":""},{"name":"withAny","lua_type":"{ComponentDefinition}?","desc":""},{"name":"without","lua_type":"{ComponentDefinition}?","desc":""}],"source":{"line":54,"path":"lib/src/World/init.lua"}}],"name":"World","desc":"A `World` contains a [`Registry`](/api/Registry) and provides means for both scoped and\\nunscoped access to entities and components.\\n\\nYou can get or create a `World` with [`Anatta.getWorld`](/api/Anatta#getWorld) and\\n[`Anatta.createWorld`](/api/Anatta#createWorld).","source":{"line":10,"path":"lib/src/World/init.lua"}}')}}]);
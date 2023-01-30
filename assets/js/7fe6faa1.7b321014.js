"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[243],{20099:e=>{e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Creates a new `Reactor` given a [`Query`](/api/Anatta#Query).","params":[{"name":"registry","desc":"","lua_type":"Registry"},{"name":"query","desc":"","lua_type":"Query"}],"returns":[],"function_type":"static","private":true,"source":{"line":44,"path":"lib/src/World/Reactor.lua"}},{"name":"withAttachments","desc":"Calls the callback every time an entity enters the `Reactor`, passing each entity and\\nits components and attaching the return value to each entity.  The callback should\\nreturn a list of connections, `Instance`s, and/or functions. When the entity later\\nleaves the `Reactor`, attached connections are disconnected, attached `Instance`s are\\ndestroyed, and attached functions are called.\\n\\n:::warning\\nYielding inside of the callback is forbidden. There are currently no protections\\nagainst this, so be careful!\\n:::","params":[{"name":"callback","desc":"","lua_type":"(entity: number, ...any) -> {RBXScriptConnection | Instance | (...) -> ()}"}],"returns":[],"function_type":"method","source":{"line":114,"path":"lib/src/World/Reactor.lua"}},{"name":"each","desc":"Iterates over the all the entities present in the `Reactor`. Calls the callback for\\neach entity, passing each entity followed by the components named in the\\n[`Query`](/api/World#Query).\\n\\n:::info\\nIt\'s safe to add or remove components inside of the callback.","params":[{"name":"callback","desc":"","lua_type":"(entity: number, ...any) -> ()"}],"returns":[],"function_type":"method","source":{"line":171,"path":"lib/src/World/Reactor.lua"}},{"name":"consumeEach","desc":"Iterates over all the entities present in the `Reactor` and clears each entity\'s\\nupdate status. Calls the callback for each entity visited during the iteration,\\npassing the entity followed by the components named in the\\n[`Query`](/api/World#Query).\\n\\nThis function effectively \\"consumes\\" all updates made to components named in\\n[`Query.withUpdated`](/api/World#Query), emptying the `Reactor`. A consumer that wants\\nto selectively consume updates should use [`consume`](#consume) instead.\\n\\n:::info\\nIt\'s safe to add or remove components inside of the callback.","params":[{"name":"callback","desc":"","lua_type":"(entity: number, ...any) -> ()"}],"returns":[],"function_type":"method","source":{"line":239,"path":"lib/src/World/Reactor.lua"}},{"name":"consume","desc":"Consumes updates made to components named in `Query.withUpdated`.","params":[{"name":"entity","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","errors":[{"lua_type":"\\"entity %d is not present in this reactor\\"","desc":"The reactor doesn\'t contain that entity."}],"source":{"line":267,"path":"lib/src/World/Reactor.lua"}},{"name":"detach","desc":"Detaches all the attachments made to this `Reactor`, destroying all attached\\n`Instance`s and disconnecting all attached connections.","params":[],"returns":[],"function_type":"method","private":true,"source":{"line":285,"path":"lib/src/World/Reactor.lua"}}],"properties":[],"types":[],"name":"Reactor","desc":"Provides scoped access to the contents of a [`Registry`](/api/World#Registry)\\naccording to a [`Query`](/api/World#Query).\\n\\nA `Reactor` is stateful and observes a [`World`\'s registry](/api/World#registry). When\\nan entity matches the [`Query`](/api/World#Query), the entity enters the `Reactor` and\\nremains present until the entity fails to match the [`Query`](/api/World#Query).\\n\\nUnlike a [`Mapper`](/api/Mapper), a `Reactor` has the ability to track updates to\\ncomponents. When a component in [`Query.withUpdated`](/api/World#Query) is replaced\\nusing [`Registry:replaceComponent`](/api/Registry#replaceComponent) or\\n[`Mapper:map`](/api/Mapper#map), the `Reactor` \\"sees\\" the replacement and considers\\nthe component updated. Updated components can then be \\"consumed\\" using\\n[`Reactor:consumeEach`](#consumeEach) or [`Reactor:consume`](#consume).\\n\\nAlso unlike a [`Mapper`](/api/Mapper), a `Reactor` has the ability to \\"attach\\"\\n`RBXScriptConnection`s and `Instance`s to entities present in the `Reactor` using\\n[`Reactor:withAttachments`](#withAttachments).\\n\\nYou can create a `Reactor` using [`World:getReactor`](/api/World#getReactor).","source":{"line":23,"path":"lib/src/World/Reactor.lua"}}')}}]);
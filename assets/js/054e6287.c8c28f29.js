"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[298],{70053:function(e){e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Creates a new `Reactor` given a [`Query`](/api/Anatta#Query).","params":[{"name":"registry","desc":"","lua_type":"Registry"},{"name":"query","desc":"","lua_type":"Query"}],"returns":[],"function_type":"static","private":true,"source":{"line":33,"path":"lib/src/World/Reactor.lua"}},{"name":"withAttachments","desc":"Calls the callback every time an entity enters the `Reactor`, passing each entity and\\nits components and attaching the return value to each entity.  The callback should\\nreturn a list of connections and/or `Instance`s. When the entity later leaves the\\n`Reactor`, attached `Instance`s are destroyed and attached connections are\\ndisconnected.","params":[{"name":"callback","desc":"","lua_type":"(number, ...any) -> {RBXScriptConnection | Instance}"}],"returns":[],"function_type":"method","source":{"line":98,"path":"lib/src/World/Reactor.lua"}},{"name":"detach","desc":"Detaches all the attachments made to this `Reactor`, destroying all attached\\n`Instance`s and disconnecting all attached connections.","params":[],"returns":[],"function_type":"method","private":true,"source":{"line":119,"path":"lib/src/World/Reactor.lua"}},{"name":"each","desc":"Iterates over the all the entities present in the `Reactor`. Calls the callback for\\neach entity, passing each entity followed by the components named in the\\n[`Query`](/api/World#Query).","params":[{"name":"callback","desc":"","lua_type":"(number, ...any)"}],"returns":[],"function_type":"method","source":{"line":138,"path":"lib/src/World/Reactor.lua"}},{"name":"consumeEach","desc":"Iterates over all the entities present in the `Reactor` and clears each entity\'s\\nupdate status. Calls the callback for each entity visited during the iteration,\\npassing the entity followed by the components named in the\\n[`Query`](/api/World#Query).\\n\\nThis function effectively \\"consumes\\" all updates made to components named in\\n[`Query.withUpdated`](/api/World#Query), emptying the `Reactor`. A consumer that wants\\nto selectively consume updates should use [`consume`](#consume) instead.","params":[{"name":"callback","desc":"","lua_type":"(number, ...any)"}],"returns":[],"function_type":"method","source":{"line":163,"path":"lib/src/World/Reactor.lua"}},{"name":"consume","desc":"Clears a given entity\'s updated status.","params":[{"name":"entity","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":186,"path":"lib/src/World/Reactor.lua"}}],"properties":[],"types":[],"name":"Reactor","desc":"Provides scoped access to the contents of a [`Registry`](/api/World#Registry)\\naccording to a [`Query`](/api/World#Query).\\n\\nA `Reactor` is stateful and observes a [`World`\'s registry](/api/World#registry). When\\nan entity matches the [`Query`](/api/World#Query), the entity enters the `Reactor` and\\nremains present until the entity fails to match the [`Query`](/api/World#Query).\\n\\nIn contrast to a [`Mapper`](/api/Mapper), a `Reactor` can track updates to components\\nnamed in [`Query.withUpdated`](/api/World#Query).\\n\\nYou can create a `Reactor` using [`World:getReactor`](/api/World#getReactor).","source":{"line":15,"path":"lib/src/World/Reactor.lua"}}')}}]);
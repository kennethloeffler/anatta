"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[298],{70053:function(e){e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Creates a new `Reactor` given a [`Query`](Anatta#Query).","params":[{"name":"registry","desc":"","lua_type":"Registry"},{"name":"query","desc":"","lua_type":"Query"}],"returns":[],"function_type":"static","private":true,"source":{"line":30,"path":"lib/src/World/Reactor.lua"}},{"name":"withAttachments","desc":"Calls the callback every time an entity enters the `Reactor`, passing each entity and\\nits components and attaching the return value to each entity.  The callback should\\nreturn a list of connections and/or `Instance`s. When the entity later leaves the\\n`Reactor`, attached `Instance`s are destroyed and attached connections are\\ndisconnected.","params":[{"name":"callback","desc":"","lua_type":"(number, ...any) -> {RBXScriptConnection | Instance}"}],"returns":[],"function_type":"method","source":{"line":98,"path":"lib/src/World/Reactor.lua"}},{"name":"detach","desc":"Detaches all the attachments made to this `Reactor`, destroying all attached\\n`Instance`s and disconnecting all attached connections.","params":[],"returns":[],"function_type":"method","private":true,"source":{"line":119,"path":"lib/src/World/Reactor.lua"}},{"name":"each","desc":"Iterates over the all the entities present in the `Reactor`. Calls the callback for\\neach entity, passing each entity followed by the components specified by the `Query`.","params":[{"name":"callback","desc":"","lua_type":"(number, ...any)"}],"returns":[],"function_type":"method","source":{"line":137,"path":"lib/src/World/Reactor.lua"}},{"name":"consumeEach","desc":"Iterates over all the entities present in the `Reactor` and clears each entity\'s set\\nof updated componants. Calls the callback for each entity, passing each entity followed\\nby the components specified by the `Query`.","params":[{"name":"callback","desc":"","lua_type":"(number, ...any)"}],"returns":[],"function_type":"method","source":{"line":157,"path":"lib/src/World/Reactor.lua"}},{"name":"consume","desc":"Clears a given entity\'s set of updated components.","params":[{"name":"entity","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":180,"path":"lib/src/World/Reactor.lua"}}],"properties":[],"types":[],"name":"Reactor","desc":"Provides scoped access to the contents of a [`Registry`](Registry) according to a\\n[`Query`](World#Query).\\n\\nA `Reactor` is stateful. In contrast to a [`Mapper`](Mapper), a `Reactor` can track\\nupdates to components with [`Query.withUpdated`](World#Query).","source":{"line":9,"path":"lib/src/World/Reactor.lua"}}')}}]);
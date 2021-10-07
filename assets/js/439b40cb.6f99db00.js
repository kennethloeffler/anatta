"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[693],{79018:function(e){e.exports=JSON.parse('{"functions":[{"name":"map","desc":"Maps over entities that satisfy the `Query`. Calls the callback for each entity,\\npassing each entity followed by the components specified by the `Query` and replacing\\nthe components in `Query.withAll` with the callback\'s return value.","params":[{"name":"callback","desc":"","lua_type":"(number, ...any) -> ...any"}],"returns":[],"function_type":"method","source":{"line":52,"path":"lib/src/World/Mapper.lua"}},{"name":"each","desc":"Iterates over all entities that satisfy the `Query`. Calls the callback for each\\nentity, passing each entity followed by the components specified by the `Query`.","params":[{"name":"callback","desc":"","lua_type":"(number, ...any)"}],"returns":[],"function_type":"method","source":{"line":70,"path":"lib/src/World/Mapper.lua"}}],"properties":[],"types":[],"name":"Mapper","desc":"Provides scoped access to a [`Registry`](Registry) according to a [`Query`](World#Query).\\n\\nA `Mapper` is stateless. In contrast to a [`Reactor`](Reactor), a `Mapper` cannot\\ntrack components with [`Query.withUpdated`](World#Query).","source":{"line":9,"path":"lib/src/World/Mapper.lua"}}')}}]);
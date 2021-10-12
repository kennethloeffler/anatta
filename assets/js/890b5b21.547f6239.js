"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[178],{99209:function(e){e.exports=JSON.parse('{"functions":[{"name":"tryFromDom","desc":"Attempts to load entity-component data from attributes and tags existing on all Roblox\\n`Instance`s in the `DataModel` into an empty [`Registry`](/api/Registry).\\n\\nComponents defined on the given [`Registry`](/api/Registry) determine what tag names are\\nused to find `Instance`s to convert.\\n\\n:::info\\nEncountering an `Instance` that fails attribute validation is a soft error. Such an\\n`Instance` is skipped and the reason for the failure is logged. Consumers with more\\ngranular requirements should use [`tryFromAttributes`](#tryFromAttributes) instead.","params":[{"name":"registry","desc":"","lua_type":"Registry"}],"returns":[],"function_type":"static","errors":[{"lua_type":"\\"Registry must be empty\\"","desc":"Only an empty Registry can load from the entire Dom."}],"source":{"line":27,"path":"lib/src/Dom/init.lua"}},{"name":"tryFromAttributes","desc":"Attempts to convert the attributes of a given `Instance` into an entity and a\\ncomponent of the given\\n[`ComponentDefinition`](/api/Anatta#ComponentDefinition). Returns a success value\\nfollowed by the entity and the converted component (if successful) or an error message\\n(if unsuccessful).","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"componentDefinition","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"boolean, number, any"}],"function_type":"static","source":{"line":43,"path":"lib/src/Dom/init.lua"}},{"name":"tryFromTagged","desc":"Attempts to convert attributes on all the `Instance`s with the `CollectionService` tag\\nmatching the pool\'s component name into entities and components.\\n\\n:::info\\nEncountering an `Instance` that fails attribute validation is a soft error. Such an\\n`Instance` is skipped and the reason for the failure is logged. Consumers with more\\ngranular requirements should use [`tryFromAttributes`](#tryFromAttributes) instead.","params":[{"name":"pool","desc":"","lua_type":"Pool"}],"returns":[],"function_type":"static","source":{"line":58,"path":"lib/src/Dom/init.lua"}},{"name":"tryToAttributes","desc":"Takes an entity, a component on the entity, and the component\'s\\n[`ComponentDefinition`](/api/Anatta#ComponentDefinition) and attempts to convert the\\ncomponent into a dictionary that can be used to set attributes on an `Instance`. The\\nkeys of the returned dictionary are the names of the requested attributes, while the\\nvalues correspond to the entity and the value(s) of the component.\\n\\nReturns a success value followed by the attribute dictionary (if successful) or an\\nerror message (if unsuccessful).\\n\\n:::info\\nThis function has side effects when components contain `Instance` references. When\\nthis is the case, a `Folder` is created under the given `Instance` and an\\n`ObjectValue` under that `Folder` for each `Instance` reference.","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"component","desc":"","lua_type":"any"},{"name":"componentDefinition","desc":"","lua_type":"ComponentDefinition"}],"returns":[{"desc":"","lua_type":"boolean, {[string]: any]}"}],"function_type":"static","source":{"line":82,"path":"lib/src/Dom/init.lua"}},{"name":"waitForRefs","desc":"","params":[],"returns":[],"function_type":"static","private":true,"yields":true,"source":{"line":90,"path":"lib/src/Dom/init.lua"}}],"properties":[],"types":[],"name":"Dom","desc":"`Dom` is a utility module used to convert components to and from attributes and\\n`CollectionService` tags on `Instance`s.","source":{"line":7,"path":"lib/src/Dom/init.lua"}}')}}]);
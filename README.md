# WorldSmith -  a game creation plugin for Roblox Studio

## Introduction

WorldSmith is an [entity-component-system](https://en.wikipedia.org/wiki/Entity–component–system) for Roblox Studio. It allows **components** to be tied to instances (which can be thought of as representing **entities**). Components consist *only of data* - all behavior lives in the **systems**. WorldSmith's interface allows a game creator to give an instance as many different components as he or she wishes; in this way, game objects can be built with extremely varied and customizable behavior with no dependency issues, and changing/adding behaviors is often as simple as editing a few component parameters/adding new components, including during runtime \[!].

### Requiring the EntityManager module
EntityManager must be required by both the server and client.

In a Script on the server (i.e. ServerScriptService):
```
local EntityManager = require(game.ReplicatedStorage.WorldSmith.EntityManager)
```

In a LocalScript on the client (i.e. StarterPlayerScripts):
```
local EntityManager = require(game.ReplicatedStorage.WorldSmith.EntityManager)
```

## Table of contents

- [The WorldSmith interface](https://github.com/kennethloeffler/WorldSmith#the-worldsmith-interface)
  - [Add component window](https://github.com/kennethloeffler/WorldSmith#add-component-window)
  - [Show components window](https://github.com/kennethloeffler/WorldSmith#show-components-window)
  - [Rigid body button](https://github.com/kennethloeffler/WorldSmith#rigid-body-button)
  - [Refresh components button](https://github.com/kennethloeffler/WorldSmith#refresh-components-button)
 - [The EntityManager class](https://github.com/kennethloeffler/WorldSmith#EntityManager)
  
## The WorldSmith interface
### Add component window
The add component window allows components to be added to the selected instance.
### Show components window
The show components window displays all the components a selected instance possesses. 
### Rigid body button
The rigid body button creates a rigid body out of a selected model - the model must have a PrimaryPart, and all BaseParts contained in the model will be rigidly attached to the PrimaryPart.
### Refresh components button
The refresh components button hot-swaps the plugin's currently loaded ComponentDesc module with the one in ReplicatedStorage.WorldSmith.

##EntityManager
EntityManager is the workhorse of the ECS - it provides many useful methods for getting and manipulating groups of entities and their components. [EntityManager.lua](https://github.com/kennethloeffler/WorldSmith/blob/master/WorldSmith/EntityManager.lua) contains a full API reference.

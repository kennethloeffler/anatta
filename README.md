# WorldSmith -  a game creation plugin for Roblox Studio

## Introduction

WorldSmith is an [entity-component-system](https://en.wikipedia.org/wiki/Entity–component–system) for Roblox Studio. It allows **components** to be tied to instances (which represent **entities**). Components consist *only of data* - all behavior lives in the **systems**. WorldSmith's interface allows a game creator to give an instance as many different components as he or she wishes; in this way, game objects can be built with extremely varied and customizable behavior with no dependency issues, and changing/adding behaviors is often as simple as editing a few component parameters/adding new components, including during runtime \[!].

## Table of contents

- [The WorldSmith interface](https://github.com/kennethloeffler/WorldSmith#the-worldsmith-interface)
  - [Add component window](https://github.com/kennethloeffler/WorldSmith#add-component-window)
  - [Show components window](https://github.com/kennethloeffler/WorldSmith#show-components-window)
  - [Parameter window](https://github.com/kennethloeffler/WorldSmith#parameter-window)
  - [Rigid body button](https://github.com/kennethloeffler/WorldSmith#rigid-body-button)
  - [Refresh components button](https://github.com/kennethloeffler/WorldSmith#refresh-components-button)
- [Components](https://github.com/kennethloeffler/WorldSmith#components)
  - [Built-in components](https://github.com/kennethloeffler/WorldSmith#built-in-components)
    - [ContextActionTrigger](https://github.com/kennethloeffler/WorldSmith#contextactiontrigger)  
    - [TouchTrigger](https://github.com/kennethloeffler/WorldSmith#touchtrigger)
    - [CharacterConstraint](https://github.com/kennethloeffler/WorldSmith#characterconstraint)
    - [TweenPartPosition](https://github.com/kennethloeffler/WorldSmith#tweenpartposition)
    - [TweenPartRotation](https://github.com/kennethloeffler/WorldSmith#tweenpartrotation)
    - [AnimatedDoor](https://github.com/kennethloeffler/WorldSmith#animateddoor)
    - [Vehicle](https://github.com/kennethloeffler/WorldSmith#vehicle)
  - [Creating custom components](https://github.com/kennethloeffler/WorldSmith#creating-custom-components)
- [Systems](https://github.com/kennethloeffler/WorldSmith#systems)
  - [Built-in systems](https://github.com/kennethloeffler/WorldSmith#built-in-systems)
    - [Client:](https://github.com/kennethloeffler/WorldSmith#client)
      - [ContextActionSystem](https://github.com/kennethloeffler/WorldSmith#contextactionsystem-client)
      - [DoorSystem](https://github.com/kennethloeffler/WorldSmith#doorsystem-client)
      - [TriggerSystem](https://github.com/kennethloeffler/WorldSmith#triggersystem-client)
      - [TweenSystem](https://github.com/kennethloeffler/WorldSmith#tweensystem-client)
      - [VehicleSystem](https://github.com/kennethloeffler/WorldSmith#vehiclesystem-client)
    - [Server:](https://github.com/kennethloeffler/WorldSmith#server)
      - [DoorSystem](https://github.com/kennethloeffler/WorldSmith#doorsystem-server)
      - [TriggerSystem](https://github.com/kennethloeffler/WorldSmith#triggersystem-server)
      - [TweenSystem](https://github.com/kennethloeffler/WorldSmith#tweensystem-server)
      - [VehicleSystem](https://github.com/kennethloeffler/WorldSmith#vehiclesystem-server)
  - [Creating custom systems](https://github.com/kennethloeffler/WorldSmith#creating-custom-systems)
  
## The WorldSmith interface
### Add component window
The add component window allows components to be added to the selected instance.
### Show components window
The show components window displays all the components a selected instance possesses. 
### Parameter window
The parameter window allows the parameters of a component to be edited.
### Rigid body button
The rigid body button creates a rigid body out of a selected model - the model must have a PrimaryPart, and all BaseParts contained in the model will be rigidly attached to the PrimaryPart.
### Refresh components button
The refresh components button hot-swaps the plugin's currently loaded ComponentInfo module with the one in ServerScriptService.WorldSmithServer. 

## Components
### Built-in components
#### ContextActionTrigger
#### TouchTrigger
#### CharacterConstraint
#### TweenPartPosition
#### TweenPartRotation
#### AnimatedDoor
#### Vehicle
### Creating custom components
Custom components may be created by editing the WorldSmithServer.ComponentInfo module. Components consist of a unique name and an arbitrary number of parameters. The idiom for defining components is as follows:
```
ComponentName = { -- declaration of a new component called "ComponentName"
  BoolParameter = "boolean" -- a boolean parameter called "BoolParameter"
  NumberParameter = "number" -- a number parameter called "NumberParameter"
  StringParameter = "string" -- a string parameter called "StringParameter"
  InstanceParameter = "Instance" -- an instance parameter called "InstanceParameter"
}
```

## Systems
### Built-in systems
#### Client
##### ContextActionSystem ##### {#client}
##### DoorSystem ##### {#client}
##### TriggerSystem ##### {#client}
##### TweenSystem ##### {#client}
##### VehicleSystem ##### {#client}
#### Server
##### DoorSystem {#server}
##### TriggerSystem {#server}
##### TweenSystem {#server}
##### VehicleSystem {#server}
### Creating custom systems
Clientside and serverside systems are each defined in ReplicatedStorage.WorldSmithClient.Systems and ServerScriptService.WorldSmithServer.Systems, respectively. Each system runs on its own thread and has access to the **entity-component map** as well as the **component-entity map**. 

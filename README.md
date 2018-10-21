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
      - ContextActionSystem
      - DoorSystem
      - TriggerSystem
      - TweenSystem
      - VehicleSystem
    - [Server:](https://github.com/kennethloeffler/WorldSmith#server)
      - DoorSystem
      - TriggerSystem
      - TweenSystem
      - VehicleSystem
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
- bool Enabled
- string desktopPC
- string mobile
- string console
- number MaxDistance
- bool CreateTouchButton
#### TouchTrigger
- bool Enabled
#### CharacterConstraint
- number CharacterPoseId
- bool Enabled
- string Label
#### TweenPartPosition
- bool Enabled
- bool LocalCoords
- bool ClientSide
- Instance Trigger
- number Time
- string EasingStyle
- string EasingDirection
- bool Reverses
- number RepeatCount
- number DelayTime
- number X, Y, Z
#### TweenPartRotation
- bool Enabled
- bool LocalCoords
- bool ClientSide
- Instance Trigger
- number Time
- string EasingStyle
- string EasingDirection
- bool Reverses
- number RepeatCount
- number DelayTime
- number X, Y, Z
#### AnimatedDoor
 - bool Enabled
 - bool AutomaticTriggers
 - number Time
 - number OpenDirection
 - number CloseDelay
 - string EasingStyle
 - number TriggerOffset
 - Instance PivotPart
 - Instance FrontTrigger
 - Instance BackTrigger
#### Vehicle
 - bool Enabled
 - Instance MainPart
 - Instance EnterTrigger
 - number AccelerationRate
 - number BrakeDeceleration
 - number MaxTurnSpeed
 - number TurnRate
 - number MaxSpeed
 - number MaxForce
 - Instance DriverConstraint
 - Instance AdditionalCharacterConstraints
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
##### ContextActionSystem
##### DoorSystem
##### TriggerSystem
##### TweenSystem
##### VehicleSystem
#### Server
##### DoorSystem
##### TriggerSystem
##### TweenSystem
##### VehicleSystem
### Creating custom systems
Clientside and serverside systems are each defined in ReplicatedStorage.WorldSmithClient.Systems and ServerScriptService.WorldSmithServer.Systems, respectively. Each system runs on its own thread and has access to the **entity-component map** as well as the **component-entity map**. 

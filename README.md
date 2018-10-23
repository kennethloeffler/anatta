# WorldSmith -  a game creation plugin for Roblox Studio

## Introduction

WorldSmith is an [entity-component-system](https://en.wikipedia.org/wiki/Entity–component–system) for Roblox Studio. It allows **components** to be tied to instances (which represent **entities**). Components consist *only of data* - all behavior lives in the **systems**. WorldSmith's interface allows a game creator to give an instance as many different components as he or she wishes; in this way, game objects can be built with extremely varied and customizable behavior with no dependency issues, and changing/adding behaviors is often as simple as editing a few component parameters/adding new components, including during runtime \[!].

### Requiring the WorldSmithServerMain and WorldSmithClientMain modules
For systems (i.e. all the game behavior) to be initialized, both of the above named modules must be required by the server and client.

In a Script on the server (i.e. ServerScriptService):
```
local WorldSmithServer = require(game.ServerScriptService.WorldSmithServer.WorldSmithServerMain)
```

In a LocalScript on the client (i.e. StarterPlayerScripts):
```
local WorldSmithClient = require(game.ReplicatedStorage.WorldSmithClient.WorldSmithClientMain)
```

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
Components are represented by Folder instances parented to their corresponding entities. They contain ValueBase instances matching the parameters defined for their component. 
### Built-in components
#### ContextActionTrigger
When a player becomes MaxDistance units away from this component's parent entity, a context action is bound on their client matching the desktopPC, mobile, and console parameters, which when triggered broadcasts an event within the component. The parent entity is expected to be a BasePart. desktopPC, mobile, and console should be comma-delineated strings specifying the input enum and type, i.e. for desktopPC: KeyCode,E
- bool Enabled
- string desktopPC
- string mobile
- string console
- number MaxDistance
- bool CreateTouchButton (NOT FULLY IMPLEMENTED)
#### TouchTrigger
When a character touches this component's parent entity, an event is fired with the component. The parent entity is expected to be a BasePart. 
- bool Enabled
#### CharacterConstraint
Specifies that this component's entity is an attachment point for characters. The parent entity is expected to be a BasePart.
- number CharacterPoseId (NOT FULLY IMPLEMENTED)
- bool Enabled
- string Label
#### TweenPartPosition
When the event(s) within "Trigger" are fired, the position of this component's parent entity will tween according to its parameters: on every client if ClientSide is false, or only on the client that triggered it if ClientSide is true. The parent entity is expected to be a BasePart. 
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
When the event(s) within "Trigger" are fired, the rotation of this component's parent entity will tween according to its parameters: on every client if ClientSide is false, or only on the client that triggered it if ClientSide is true. The parent entity is expected to be a BasePart. 
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
When this component is given to an instance, all of the BaseParts contained within the instance will be rigidly attached to PivotPart. When the event(s) within "BackTrigger" or "FrontTrigger" are fired, the rotation of PivotPart will tween -90 or 90 degrees (depending on which trigger was fired), and then back on each client. If AutomaticTriggers is set to true, two TouchTriggers will be automatically generated for BackTrigger and FrontTrigger; TriggerOffset controls how far these triggers are placed away from the center of the door.
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
When this component is given to an instance, all of the BaseParts contained within the instance will be rigidly attached to MainPart. When the event within EnterTrigger is fired, the player who fired it will be attached to the parent entity of DriverConstraint (expected to be a CharacterConstraint) and if they are the first player to enter, they will be given control of the vehicle. 
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
 - Instance AdditionalCharacterConstraints (NOT FULLY IMPLEMENTED)
### Creating custom components
Custom components may be created by editing the WorldSmithServer.ComponentInfo module. Components consist of a unique name and an arbitrary number of parameters. The idiom for defining components is as follows:
```
ComponentName = { -- declaration of a new component called "ComponentName"
  BoolParameter = "boolean", -- a boolean parameter called "BoolParameter"
  NumberParameter = "number", -- a number parameter called "NumberParameter"
  StringParameter = "string", -- a string parameter called "StringParameter"
  InstanceParameter = "Instance", -- an instance parameter called "InstanceParameter"
  ["_init"] = function(parameters, component) -- a function called when this component is created via the plugin interface
  end
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
Clientside and serverside systems are each defined in ReplicatedStorage.WorldSmithClient.Systems and ServerScriptService.WorldSmithServer.Systems, respectively. Each system runs on its own thread and has access to the **entity-component map** as well as the **component-entity map**. Examples of system implementations can be found by looking at the built-in systems defined in ReplicatedStorage.WorldSmithClient.Systems and ServerScriptService.WorldSmithServer.Systems.

All a system needs to run is a ```Start()```  function within the module's return value. The entity-component map and the component-entity map are passed to this function (in that order). 

#### Communicating between components
Sometimes components need to communicate; this should be done in the systems. In general, there are three ways by which components may communicate with each other; [these are described in detail here.](http://gameprogrammingpatterns.com/component.html#how-do-components-communicate-with-each-other) For reference, the built-in systems almost exclusively use the 2nd pattern described in the link.

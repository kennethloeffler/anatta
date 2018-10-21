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
  - [Built-in components](https://github.com/kennethloeffler/WorldSmith#builtin-components)
    - [TouchTrigger](https://github.com/kennethloeffler/WorldSmith#touchtrigger)
  - [Creating custom components](https://github.com/kennethloeffler/WorldSmith#creating-custom-components)
- [Systems](https://github.com/kennethloeffler/WorldSmith#systems)
  - [Built-in systems](https://github.com/kennethloeffler/WorldSmith#builtin-systems)
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


### Built-in components

## Systems

### Refresh components button

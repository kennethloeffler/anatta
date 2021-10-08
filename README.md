# Intro

The entity component system (aka ECS, entity system) is an architectural pattern that represents game objects with *entities* (unique IDs - essentially just numbers) associated with various *components* (pure data - no behavior) that represent units of state. Systems proper are free functions called each frame (or at some other frequency) that select all the entities fulfilling some criteria (e.g. all entities with both a `Health` component and a `Regeneration` component). For more details see:

* [A Data-Driven Game Object System](https://www.gamedevs.org/uploads/data-driven-game-object-system.pdf)
* [Evolve Your Hierarchy](http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
* [Entity Systems are the future of MMOG development](http://t-machine.org/index.php/2007/09/03/entity-systems-are-the-future-of-mmog-development-part-1/)
* [Data-oriented design book](https://www.dataorienteddesign.com/dodbook/)
* [ECS back and forth](https://skypjack.github.io/2019-02-14-ecs-baf-part-1/)

Anatta is a library that integrates the ECS pattern into Roblox. Anatta aims to provide all that is reasonably necessary to use ECS to develop a Roblox game, but no more. Anatta provides infrastructure to:

* Represent game state with entities and components
* Define components with introspectable types and perform validation automatically
* Create expressive queries that can be used to iterate over entities and their components
* Convert entities and components between Roblox `Instance` attributes and their preferred representation

Anatta is not a framework. Structure your code however you'd like!

# Motivation

An entity component system for use on Roblox was originally motivated by the inadequacy of the `DataModel` to elegantly solve problems with state and identity - particularly when `Workspace.StreamingEnabled` is set, when uniquely replicating `Instance`s via `PlayerGui` (where each client in a typical setup has their own copy of the `Instance`), or in other cases when there is not necessarily a one-to-one correspondence between an `Instance` and a logical game object.

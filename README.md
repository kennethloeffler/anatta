<p align="center"><b>This library is currently in an incomplete, experimental state - use at your own risk!</b></p>

# Intro

The entity component system (aka ECS, entity system) is an architectural pattern which models an application as a collection of entities associated with various component value objects which represent units of state. Systems proper are free functions called each frame (or at some other frequency) which operate on entities fulfilling some criteria (e.g. all entities with both a `Health` component and a `Regeneration` component). However, systems need not strictly adhere to this; they can have state, for example, or be implemented in terms of events without issue. For details see:

* [A Data-Driven Game Object System](https://www.gamedevs.org/uploads/data-driven-game-object-system.pdf)
* [Evolve Your Hierarchy](http://cowboyprogramming.com/2007/01/05/evolve-your-heir achy/)
* [Entity Systems are the future of MMOG development](http://t-machine.org/index.php/2007/09/03/entity-systems-are-the-future-of-mmog-development-part-1/)
* [ECS back and forth](https://skypjack.github.io/2019-02-14-ecs-baf-part-1/)

# Motivation

An entity component system for use on Roblox was mainly motivated by the inadequacy of the `DataModel` to elegantly solve problems with state and identity - particularly when `Workspace.StreamingEnabled` is set, when uniquely replicating `Instance`s via `PlayerGui` (where each client in a typical setup has their own copy of the `Instance`), or in other cases when there is not necessarily a one-to-one correspondence between an `Instance` and a logical game object. See the wiki (after I write it, anyway :zany_face:) for further information on how to use the library, examples and use cases, and some common pitfalls.

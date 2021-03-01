Anatta is a library for dealing with the problem of state in Roblox games. It implements the entity component system, an architectural pattern where each game object is represented by an ID (entity) associated with one or more plain data structures (components). Systems may then apply transformations to sets of entities with specific components. For more background, see:

* [A Data-Driven Game Object System](https://www.gamedevs.org/uploads/data-driven-game-object-system.pdf)
* [Evolve Your Hierarchy](http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
* [Entity Systems are the future of MMOG development](http://t-machine.org/index.php/2007/09/03/entity-systems-are-the-future-of-mmog-development-part-1/)
* [Data-oriented design book](https://www.dataorienteddesign.com/dodbook/)
* [ECS back and forth](https://skypjack.github.io/2019-02-14-ecs-baf-part-1/)

# Concepts

* An entity is a numeric ID representing a logical game object: a door, monster, level, status effect, whatever!

* A component is plain data associated with one entity. It shouldn't contain functions or have methods. In Roblox, this requirement can be relaxed to accommodate `Instance`-typed components and members (among others).

* The registry stores entities and their components. It provides methods to create and destroy entities, and get, set, update, or test for any component or set of components on an entity.

* A system provides behavior for entities that have a particular combination of required, forbidden, and updated components. Considered together, these entities are called the system's collection.
	* A system can be pure or impure:
		* A pure system:
			* only has access to its collection;
			* is expected to return only new or unchanged components when processing each entity;
			* cannot track updated components;
			* cannot listen for entities entering or leaving its collection.
		* An impure system:
			* has access to both its collection and the registry;
			* can freely add, remove, and mutate components via the registry;
			* can track updates to components;
			* can listen for entities entering or leaving its collection.

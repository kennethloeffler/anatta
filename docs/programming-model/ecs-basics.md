# ECS basics for Roblox programmers

ECS architectures are uncommon on Roblox, so many Roblox developers may not know much about them or how they can be used. In this section, we'll compare and contrast ECS with another kind of component-based architecture that's more common on Roblox: the "binder" pattern. Then, we'll incrementally alter `CollectionService`'s API, turning it into one that resembles Anatta's API.

First, a quick refresher on the essentials of `CollectionService`:
```lua
local CollectionService = game:GetService("CollectionService")

local dancerCount = 0

CollectionService:GetInstanceAddedSignal("Dancing"):Connect(function(instance)
	print("Woah, sick moves!")
	dancerCount += 1
end)

CollectionService:GetInstanceRemovedSignal("Dancing"):Connect(function(instance)
	print("Why'd you stop? :(")
	dancerCount -= 1
end)

for _ = 1, 100 do
	-- Doesn't have to be a Part - can be any Instance
	CollectionService:AddTag(instance, "Dancing")
end

assert(dancerCount == 100, "There should be 100 dancers.")

for _ = 1, 66 do
	CollectionService:RemoveTag(instance, "Dancing")
end

assert(dancerCount == 44, "There should only be 44 dancers now.")

-- We want to compliment each dancer every ten seconds.
while true do
	task.wait(10)
	for _, instance in ipairs(CollectionService:GetTagged("Dancing")) do
		print(("Sick moves, %s!"):format(instance.name))
	end
end
```

We can immediately see that this allows us to:

* Listen for addition and removal of tags to know when to alter game state;
* Make a *query* at any time to discover all the `Instance`s that possess the tag and run the same logic for all of them.

We'll see in the following sections how we can leverage these ideas and improve upon them.

## The binder pattern

Architectures using the "binder" pattern on Roblox have utilized this API with minimal extension to implement OOP-style object composition to some success.

## Supercharging `CollectionService`

### Keeping tags well-defined

Let's invent a fictitious method called `CollectionService:DefineTag`. For now, it won't do much - we'll just make `CollectionService` throw an error if it ever receives an undefined tag name:
```lua
local CollectionService = game:GetService("CollectionService")

local success = pcall(function()
	CollectionService:GetTagged("OhNo!")
end)

assert(success == false, "CollectionService should throw when given an undefined tag name.")

CollectionService:DefineTag("OhNo!")

-- This won't error because we've just defined the tag.
CollectionService:GetTagged("OhNo!")
```
This helps for debugging simple problems like typos in tag names.

### Getting the data we want

### Making expressive queries

## Replacing `Instance`

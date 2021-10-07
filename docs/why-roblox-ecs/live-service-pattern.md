# A Pattern Born for Live-Service Games

Most games on Roblox are developed as *live-service games*. They are also called *games as a service* or simply *live games*. Regardless of the term we use, it just refers to games that use a recurring revenue model. Development doesn't stop after launch; the product is continuously upgraded and sold. This usually means that a decent chunk of development time will be spent creating content for the game: new cosmetic items, gameplay areas, storylines, promotional events.

Players in multiplayer games talk to each other, sharing personal knowledge and secrets of the game. This is good for community effects, but can have the unfortunate side effect of players consuming content much faster than they otherwise would. The problem gets worse the larger and more intertwined a game's community becomes. To maintain a very successful game, massive amounts of content must be produced - quickly, efficiently, and regularly. Creating all this content takes a lot of time. Large teams have to be built to just barely keep up.

Sometimes a new piece of content requires a piece of game logic to change or work with another in unanticipated ways. Other times a player has discovered a game-breaking strategy that demands a change to an integral part of the game logic. The code must be easy to change and debug: requirements that cut right across engineering concerns are inevitably introduced ("can you make me a gun that shoots swords?"), so it's also important that the programming model doesn't fall apart in fundamental ways when this happens.

As experiences grow larger and more complex, there is an ever-increasing amount of data to worry about persisting. This may bring to mind things like players' storyline progress, collectibles, stats, and lifetime achievements, but it also includes things like items, ability types, and even different areas and zones in the game. On a live-service game, all of it might be important someday, so it should be kept in a format that's easy to inspect and transform.

To keep it short, content is data, and properly dealing with it can have outsized impact on ease of development.

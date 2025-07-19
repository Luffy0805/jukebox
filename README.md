# Minetest Mod: Jukebox

By Luffy0805
Credits: turrican
Version: 1.0.0
License: MIT

---

## Description

This mod adds various music-related elements to Minetest:

* Functional jukeboxes, turntables, and DJ turntables
* Decorative consoles (classic or DJ) with built-in inventory
* Custom vinyl records
* Spatial sound system with listening distance
* Animated musical particles
* Automatic vinyl ejection

## Installation

1. Place the mod in Minetest's `mods/` folder
2. Enable the mod in the desired world
3. All audio files must be in `.ogg` format and **MONO**, not *STEREO*
4. Optional: `basic_materials` dependency to craft vinyls using plastic

## Adding a Vinyl

1. Place the `.ogg` file in the mod's `sounds/` folder (e.g., `song4.ogg` — you can choose any name as long as it's correctly referenced in the code)

2. In `init.lua`, add an entry to the `music_discs` table (around line 60) :

   ```lua
   ["jukebox:vinyl4"] = {  -- or vinyl5, vinyl6... depending on the number
       name = "S4", -- must be "S" followed by the number
       description = "Artist name or title",
       file = "song4", -- any name
       duration = 195, -- in seconds
       color = "#FF8800", -- hexadecimal jukebox color code
       texture = "s4.png" -- can be modified
   }
   ```

Vinyl crafting recipes are usually pre-filled. You only need to add duration and name. If you're adding a new one, copy the code above, change the vinyl number (e.g., vinyl10), and add a new texture.
In that case, modify this line (line 725):

```lua
for i = 1, 7 do
    core.register_craft({
        output = "jukebox:vinyl" .. i,
        recipe = {
            {plastic, "dye:black", plastic},
            {plastic, "dye:" .. dyes[i], plastic},
            {plastic, "dye:black", plastic}
        }
    })
end
```

Change "7" to match the total number of vinyls.

3. Check that the texture limit for vinyls is not exceeded. The mod includes 7 by default. If needed, add more textures and update the code accordingly.

4. Add the vinyl color to the `vinyle_crafts` recipe list (line 722) :

```lua
local dyes = {"red", "green", "yellow", "white", "blue", "cyan", "black", "yourcolor"}
```

Just insert your vinyl color in the correct order.

## Vinyl Crafting

Each vinyl is crafted using a black material + a dye. Example recipe:

\[ plastic ]\[ black dye ]\[ plastic ]
\[ plastic ]\[ white dye ]\[ plastic ]
\[ plastic ]\[ black dye ]\[ plastic ]

## How It Works

* Punch with a vinyl to play music
* Punch again to stop music and eject the vinyl
* Sound is spatialized: only nearby players can hear it
* Musical particles (note1.png to note9.png), no color tinting
* Dynamic infotext showing title, artist, and duration
* Automatic ejection of the record when music ends 
* Right-click consoles to open the built-in inventory

## Included Blocks

| Block Name           | Function                             | Height   |
| -------------------- | ------------------------------------ | -------- |
| jukebox\:jukebox     | Plays vinyls                         | 1 block  |
| jukebox\:platine     | Styled version                       | 1 block  |
| jukebox\:platine\_dj | Functional DJ turntable              | 0.25 blk |
| jukebox\:console     | Decorative console with inventory    | 1 block  |
| jukebox\:console\_dj | DJ decorative console with inventory | 0.25 blk |
| jukebox\:bloc\_dj    | Decorative DJ block                  | 1 block  |

## Default Audio Settings (in init.lua, line 4) 

```lua
particle_lifetime = 1.5, -- Lifetime of a particle before it disappears
fade_in_time = 0, -- Volume fades out with distance
particle_spawn_interval = 0.75, -- A particle spawns every 0.75 seconds
max_hear_distance = 50, -- Max distance at which players can hear music
sound_gain = 0.85, -- Volume level
sound_check_interval = 1.0, -- How often to check player distance during playback
```

## Important Notes

* All audio files must be in MONO (otherwise they won't play)
* Use Audacity to convert: `Tracks > Mix > Mono`
* To convert MP3s, use tools like convertio.co — make sure to set it to MONO in conversion settings
* Vinyl and particle textures must be in the `textures/` folder

## Recommended Folder Structure

```
mods/
└── jukebox/
    ├── mod.conf
    ├── LICENSE.txt
    ├── README.md
    ├── README-fr.txt
    ├── init.lua
    ├── sounds/
    │   └── songX.ogg
    ├── textures/
    │   ├── sX.png
    │   ├── note1.png ... note9.png
    │   └── jukebox_top.png, platine_top.png ...
    └── locale/
        ├── jukebox.en.tr
        └── jukebox.fr.tr
```

## End.

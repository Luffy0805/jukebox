local modname = core.get_current_modname()
local S = core.get_translator(modname) -- Module permetant la traduction, seulement l'anglais et le francais sont dispo

local config = {
    particle_lifetime = 1.5, -- Temps de vie d'une particle avant quelle disparaisse
    fade_in_time = 0, -- Diminution du son lors de la lecture (Plus on s'éloigne, plus le son diminue)
    particle_spawn_interval = 0.75, -- Toute les 0.75 secondes une nouvelle particle apparaitront
    max_hear_distance = 50, -- Distance maximale à laquelle les joueurs peuvent entendre la musique
    sound_gain = 0.85, -- Volume du son
    sound_check_interval = 1.0, -- Intervale de vérification de distance pour le son quand une musique est en cours
}

-- Probleme de dépense de fonction avec eject_disc et stop_jukebox (dépéndance circulaire)
eject = {}


local jukebox_music_particle_textures = {
    "note1.png",
    "note2.png",
    "note3.png",
    "note4.png",
    "note5.png",
    "note6.png",
    "note7.png",
    "note8.png",
    "note9.png",
}

local last_texture_index = 0

-- On définit les disques de musique disponibles
-- Chaque disque a un nom, une description, un fichier audio, une durée, une couleur
-- Attention les fichier audio doivent etre en MONO et non en STEREO!
local music_discs = {
    ["jukebox:vinyl1"] = {
        name = "S1 Azizam",
        description = "EdSheeran",
        file = "song1",
        duration = 165,
        color = "#E91E63",
        texture = "s1.png"
    },
    ["jukebox:vinyl2"] = {
        name = "S2",
        description = "Turrican et Luffy",
        file = "song2",
        duration = 219,
        color = "#37da1e",
		glow = 15,
        texture = "s2.png"
    },
    ["jukebox:vinyl3"] = {
        name = "S3",
        description = "La Reine Amelaye",
        file = "song3",
        duration = 189,
        color = "#fbf538",
        texture = "s3.png"
    }
}

local active_jukeboxes = {}

-- On calcule la distance simple entre deux positions avec le théoreme de pythagore
local function calculate_distance(pos1, pos2)
    if not pos1 or not pos2 then return math.huge end
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function check_players_in_range(pos, max_distance)
    local players_in_range = {}
    local connected_players = core.get_connected_players()

    for _, player in pairs(connected_players) do
        if player and player:is_player() then
            local player_pos = player:get_pos()
            if player_pos then
                local distance = calculate_distance(pos, player_pos)
                if distance <= max_distance then
                    table.insert(players_in_range, player:get_player_name())
                end
            end
        end
    end

    return players_in_range
end

local function spawn_music_particles(pos, node, disc_name)
    if not pos or not node then return end

    local vx = (math.random() - 0.5) * 0.1
    local vz = (math.random() - 0.5) * 0.1
    local vy = 0.15 + math.random() * 0.1

    local texture_index
    repeat
        texture_index = math.random(#jukebox_music_particle_textures)
    until texture_index ~= last_texture_index or #jukebox_music_particle_textures == 1

    last_texture_index = texture_index

    local selected_texture = jukebox_music_particle_textures[texture_index]

    core.add_particle({
        pos = {
            x = pos.x + (math.random() - 0.5) * 0.6,
            y = pos.y + 0.9,
            z = pos.z + (math.random() - 0.5) * 0.6
        },
        velocity = {x = vx, y = vy, z = vz},
        acceleration = {x = 0, y = 1, z = 0},
        expirationtime = config.particle_lifetime,
        size = math.random(4, 5),
        collisiondetection = true,
        collision_removal = false,
        texture = selected_texture,
        glow = 1,
    })
end

-- Redémarre le son pour les joueurs dans la porté, en tenant compte du temps écoulé (music)
local function restart_sound_for_players(pos, disc_data, players_in_range)
    local pos_hash = core.hash_node_position(pos)
    local jukebox_data = active_jukeboxes[pos_hash]

    if not jukebox_data then
        return false
    end

    if jukebox_data.sound then
        core.sound_stop(jukebox_data.sound)
    end

    -- On determine le temps écoulé depuis le début de la musique
    local elapsed_time = core.get_gametime() - jukebox_data.start_time
    local remaining_time = disc_data.duration - elapsed_time -- Temps restant de la musique avec le elapsed_time

    if remaining_time <= 0 then
        stop_jukebox(pos)
        return false
    end

    for _, player_name in pairs(players_in_range) do
        local sound = core.sound_play(disc_data.file, {
            pos = pos,
            to_player = player_name,
            max_hear_distance = config.max_hear_distance,
            gain = config.sound_gain,
            fade = config.fade_in_time,
            start_time = elapsed_time,
            loop = false
        })

        if sound and not jukebox_data.sound then
            jukebox_data.sound = sound
        end
    end

    return true
end

local function update_sound(pos, disc_data)
    local pos_hash = core.hash_node_position(pos)
    local jukebox_data = active_jukeboxes[pos_hash]

    if not jukebox_data then
        return
    end

    local players_in_range = check_players_in_range(pos, config.max_hear_distance) -- On regarde les joueurs dans la porter 

    if #players_in_range == 0 then
        if jukebox_data.sound then
            core.sound_stop(jukebox_data.sound)
            jukebox_data.sound = nil
        end
    else
        if not jukebox_data.sound then
            restart_sound_for_players(pos, disc_data, players_in_range)
        end
    end

    jukebox_data.distance_check_timer = core.after(config.sound_check_interval, function()
        update_sound(pos, disc_data)
    end)
end

local function update_jukebox_infotext(pos, disc_name)
    local meta = core.get_meta(pos)
	local node = minetest.get_node(pos)
    local block_name = node.name

    if disc_name then
        local disc_data = music_discs[disc_name]
        if disc_data then
            local duration_minutes = math.floor(disc_data.duration / 60)
            local duration_seconds = disc_data.duration % 60
            local duration_str = string.format("%d:%02d", duration_minutes, duration_seconds)

            local infotext = S("Currently Playing: ") .. disc_data.name ..
                           "\n" .. S("Artist: ") .. disc_data.description ..
                           "\n" .. S("Duration: ") .. duration_str
            meta:set_string("infotext", infotext)
        end
    else
        
		if block_name == "jukebox:jukebox" then
			meta:set_string("infotext", S("Jukebox") .. "\n" .. S("Punch with a music disc to play"))
		end
		if block_name == "jukebox:platine" then
			meta:set_string("infotext", S("Platine") .. "\n" .. S("Punch with a music disc to play"))
		end
		if block_name == "jukebox:platine_dj" then
			meta:set_string("infotext", S("Platine DJ") .. "\n" .. S("Punch with a music disc to play"))
		end		
    end
end

local function stop_jukebox(pos, should_eject)
    if not pos then return end

    local pos_hash = core.hash_node_position(pos)
    local jukebox_data = active_jukeboxes[pos_hash]

    if jukebox_data then
        if jukebox_data.sound then
            core.sound_stop(jukebox_data.sound)
        end

        if jukebox_data.particle_timer then
            jukebox_data.particle_timer:cancel()
        end
        if jukebox_data.music_timer then
            jukebox_data.music_timer:cancel()
        end
        if jukebox_data.distance_check_timer then
            jukebox_data.distance_check_timer:cancel()
        end

        if should_eject and jukebox_data.disc_name then
            eject.eject_disc(pos, jukebox_data.disc_name)
        end

        update_jukebox_infotext(pos, nil)
        active_jukeboxes[pos_hash] = nil

    end
end

-- On expulse le disque proche du block de jukebox en hauteur
-- On ajoute une petite vélocité aléatoire pour donné un effet de lancement
-- Et on stop la musique en cours s'il y en avait une
function eject.eject_disc(pos, disc_name)
    if not pos or not disc_name then return end

    local node = core.get_node(pos)
    local block_name = node.name

    local eject_height = 0.5 -- Hauteur par défaut

    if block_name == "jukebox:platine_dj" then
        eject_height = -0.2
    end

    local eject_pos = {x = pos.x, y = pos.y + eject_height, z = pos.z}

    local obj = core.add_item(eject_pos, disc_name)
    if obj then
        obj:set_velocity({
            x = (math.random() - 0.5) * 2,
            y = 3,
            z = (math.random() - 0.5) * 2
        })
    end

    stop_jukebox(pos)
end

local function start_jukebox(pos, disc_name)
    if not pos or not disc_name then return false end

    local pos_hash = core.hash_node_position(pos)
    local disc_data = music_discs[disc_name]

    if not disc_data then
        core.log("error", S("Disk not found: ") .. tostring(disc_name))
        return false
    end

    stop_jukebox(pos)

    local players_in_range = check_players_in_range(pos, config.max_hear_distance)

    local sound = nil

    if #players_in_range > 0 then
        sound = core.sound_play(disc_data.file, {
            pos = pos,
            max_hear_distance = config.max_hear_distance,
            gain = config.sound_gain,
            fade = config.fade_in_time,
            loop = false
        })

        if not sound then
            core.log("error", S("Unable to play sound: ") .. disc_data.file)
            return false
        end
    end

    -- Eh oui une fonction dans une fonction, c'est pas beau mais sa marche
    -- On crée une boucle pour faire apparaitre les particles de musique
    local function spawn_particles_loop()
        local current_data = active_jukeboxes[pos_hash]
        if current_data then
            spawn_music_particles(pos, core.get_node(pos), disc_name)
            current_data.particle_timer = core.after(config.particle_spawn_interval, spawn_particles_loop)
        end
    end

    local music_timer = core.after(disc_data.duration, function()
        stop_jukebox(pos, true)  -- true = éjecter le disque
    end)

    active_jukeboxes[pos_hash] = {
        disc_name = disc_name,
        sound = sound,
        particle_timer = nil,
        music_timer = music_timer,
        distance_check_timer = nil,
        start_time = core.get_gametime()
    }

    update_jukebox_infotext(pos, disc_name)
    spawn_particles_loop()
    update_sound(pos, disc_data)

    return true
end

-- Verification si l'item est belle et bien un disque de musique
-- On regarde si le nom de l'item est dans la liste des disques de musique si non alors ce n'en est pas un
local function is_music_disc(item_name)
    return music_discs[item_name] ~= nil
end

core.register_node("jukebox:jukebox", {
    description = S("Jukebox"),
    tiles = {
        "jukebox_top.png", "default_wood.png", "jukebox_side_lr.png",
        "jukebox_side_lr.png", "jukebox_side_fb.png", "jukebox_side_fb.png",
    },
    paramtype2 = "facedir",
    groups = {choppy = 2, oddly_breakable_by_hand = 2},
    sounds = default.node_sound_wood_defaults(),
    on_punch = function(pos, node, puncher, pointed_thing)
        if not puncher or not puncher:is_player() then
            return
        end

        local pos_hash = core.hash_node_position(pos)
        local jukebox_data = active_jukeboxes[pos_hash]
        local wielded_item = puncher:get_wielded_item()
        local item_name = wielded_item:get_name()

        if jukebox_data then
            eject.eject_disc(pos, jukebox_data.disc_name)
            --core.chat_send_player(puncher:get_player_name(), S("Music stopped and disc ejected"))
        elseif is_music_disc(item_name) then
            wielded_item:take_item()
            puncher:set_wielded_item(wielded_item)
            if start_jukebox(pos, item_name) then
                local disc_data = music_discs[item_name]
                core.chat_send_player(puncher:get_player_name(), S("Currently reading: ") .. disc_data.description)
            else
                puncher:get_inventory():add_item("main", item_name)
                core.chat_send_player(puncher:get_player_name(), S("Error reading disk!"))
            end
        else
            --core.chat_send_player(puncher:get_player_name(), S("Use a music disc to play music!"))
        end
    end,
    on_destruct = function(pos)
        stop_jukebox(pos)
    end,
    can_dig = function(pos)
        local pos_hash = core.hash_node_position(pos)
        return not active_jukeboxes[pos_hash]
    end
})

-- Definition des disques de musiques
for disc_name, disc_data in pairs(music_discs) do


    core.register_craftitem(disc_name, {
        description = "Disque Musical - " .. disc_data.name .. "\n" .. 
                     core.colorize("#888888", disc_data.description) .. "\n" ..
                     core.colorize(disc_data.color, "Durée: " .. 
                     math.floor(disc_data.duration / 60) .. ":" .. 
                     string.format("%02d", disc_data.duration % 60)),
        inventory_image = disc_data.texture or "empy_disc.png",
        stack_max = 1,
        groups = {music_disc = 1}
    })


end

-- Quand le serveur shutdown alors on ejecte tout les disques en cour de lecture
--[[
core.register_on_shutdown(function()
    for pos_hash, jukebox_data in pairs(active_jukeboxes) do
        if jukebox_data and jukebox_data.disc_name then
            local pos = core.get_position_from_hash(pos_hash)
            if pos then
                eject.eject_disc(pos, jukebox_data.disc_name)
            end
        end
    end
end)
]]--

core.register_on_mods_loaded(function()
    for pos_hash, jukebox_data in pairs(active_jukeboxes) do
        if jukebox_data and jukebox_data.disc_name then
            local pos = core.get_position_from_hash(pos_hash)
            if pos then
                start_jukebox(pos, jukebox_data.disc_name)
            end
        end
    end
end)

core.register_node("jukebox:platine", {
    description = S("Platine"),
    tiles = {
        "platine_top.png", "default_wood.png", "platine_side.png",
        "platine_side.png", "platine_side.png", "platine_side_front.png",
    },
    paramtype2 = "facedir",
    groups = {choppy = 2, oddly_breakable_by_hand = 2},
    sounds = default.node_sound_wood_defaults(),
    on_punch = function(pos, node, puncher, pointed_thing)
        if not puncher or not puncher:is_player() then
            return
        end

        local pos_hash = core.hash_node_position(pos)
        local jukebox_data = active_jukeboxes[pos_hash]
        local wielded_item = puncher:get_wielded_item()
        local item_name = wielded_item:get_name()

        if jukebox_data then
            eject.eject_disc(pos, jukebox_data.disc_name)
            --core.chat_send_player(puncher:get_player_name(), S("Music stopped and disc ejected"))
        elseif is_music_disc(item_name) then
            wielded_item:take_item()
            puncher:set_wielded_item(wielded_item)
            if start_jukebox(pos, item_name) then
                local disc_data = music_discs[item_name]
                core.chat_send_player(puncher:get_player_name(), S("Currently reading: ") .. disc_data.description)
            else
                puncher:get_inventory():add_item("main", item_name)
                core.chat_send_player(puncher:get_player_name(), S("Error reading disk!"))
            end
        else
            --core.chat_send_player(puncher:get_player_name(), S("Use a music disc to play music!"))
        end
    end,

    on_destruct = function(pos)
        stop_jukebox(pos)
    end,

    can_dig = function(pos)
        local pos_hash = core.hash_node_position(pos)
        return not active_jukeboxes[pos_hash]
    end,
})

minetest.register_node("jukebox:console", {
	description = "Console",
	tiles = {
		"console_top.png",
		"console_side.png", "console_side.png",
		"console_side.png", "console_side.png", "console_side.png",
	},
	groups = {choppy = 2, oddly_breakable_by_hand = 2},
	paramtype2 = "facedir",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = { {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5} }, -- hauteur 1 bloc
	},
	selection_box = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
	},
	collision_box = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("storage", 6 * 4)
		meta:set_string("formspec",
			"size[9,10.5]" ..
			"bgcolor[#080808BB;true]" ..
			"list[current_name;storage;1.5,0.2;6,6;]" ..
			"list[current_player;main;0.5,6.5;8,4;]")
	end,

	on_rightclick = function(pos, node, clicker)
		local meta = minetest.get_meta(pos)
		local fs = meta:get_string("formspec")
		minetest.show_formspec(clicker:get_player_name(), "jukebox:console", fs)
	end,

	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("storage")
	end,
})

minetest.register_node("jukebox:platine_dj", {
    description = "Platine DJ",
    tiles = {
        "platine_dj_top.png",
        "platine_dj_side.png",
        "platine_dj_side.png",
        "platine_dj_side.png",
        "platine_dj_side.png",
        "platine_dj_side.png",
    },
    groups = {choppy = 2, oddly_breakable_by_hand = 2},
    paramtype2 = "facedir",
    drawtype = "nodebox",
    node_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5}, -- Hauteur : 0.4 bloc (0.5 - 0.1)
        },
    },
    selection_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5},
    },
    collision_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5},
    },

    on_punch = function(pos, node, puncher, pointed_thing)
        if not puncher or not puncher:is_player() then
            return
        end

        local pos_hash = core.hash_node_position(pos)
        local jukebox_data = active_jukeboxes[pos_hash]
        local wielded_item = puncher:get_wielded_item()
        local item_name = wielded_item:get_name()

        if jukebox_data then
            eject.eject_disc(pos, jukebox_data.disc_name)
            --core.chat_send_player(puncher:get_player_name(), S("Music stopped and disc ejected"))
        elseif is_music_disc(item_name) then
            wielded_item:take_item()
            puncher:set_wielded_item(wielded_item)
            if start_jukebox(pos, item_name) then
                local disc_data = music_discs[item_name]
                core.chat_send_player(puncher:get_player_name(), S("Currently reading: ") .. disc_data.description)
            else
                puncher:get_inventory():add_item("main", item_name)
                core.chat_send_player(puncher:get_player_name(), S("Error reading disk!"))
            end
        else
            --core.chat_send_player(puncher:get_player_name(), S("Use a music disc to play music!"))
        end
    end,

    on_destruct = function(pos)
        stop_jukebox(pos)
    end,

    can_dig = function(pos)
        local pos_hash = core.hash_node_position(pos)
        return not active_jukeboxes[pos_hash]
    end,
})

minetest.register_node("jukebox:console_dj", {
	description = "Console DJ",
	tiles = {
		"console_dj_top.png",
		"console_dj_side.png", "console_dj_side.png",
		"console_dj_side.png", "console_dj_side.png", "console_dj_side.png",
	},
	groups = {choppy = 2, oddly_breakable_by_hand = 2},
	paramtype2 = "facedir",
	drawtype = "nodebox",
	node_box = { type = "fixed", fixed = { {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5} } },
	selection_box = { type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.23, 0.5} },
	collision_box = { type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5} },

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("storage", 6 * 2)
		meta:set_string("formspec",
			"size[9,10.5]" ..
			"bgcolor[#080808BB;true]" ..
			"list[current_name;storage;1.5,0.2;6,6;]" ..
			"list[current_player;main;0.5,6.5;8,4;]")
	end,

	on_rightclick = function(pos, node, clicker)
		local meta = minetest.get_meta(pos)
		local fs = meta:get_string("formspec")
		minetest.show_formspec(clicker:get_player_name(), "jukebox:console_dj", fs)
	end,

	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("storage")
	end,
})



minetest.register_node("jukebox:bloc_dj", {
    description = "Bloc DJ",
    tiles = {
        "bloc_dj.png"
    },
    groups = {choppy = 2, oddly_breakable_by_hand = 2},
    paramtype2 = "facedir",
    drawtype = "nodebox",
    node_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}, -- Hauteur 0.4 bloc
        },
    },
    selection_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
    },
    collision_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
    },
})




minetest.register_craft({
    output = "jukebox:jukebox",
    recipe = {
        {"default:wood", "default:steel_ingot", "default:wood"},
        {"default:wood", "default:diamond", "default:wood"},
        {"default:wood", "default:wood", "default:wood"},
    }
})

minetest.register_craft({
    output = "jukebox:platine",
    recipe = {
        {"default:steel_ingot", "default:glass", "default:steel_ingot"},
        {"default:wood", "default:diamond", "default:wood"},
        {"default:wood", "default:wood", "default:wood"},
    }
})

minetest.register_craft({
    output = "jukebox:console",
    recipe = {
        {"default:steel_ingot", "default:glass", "default:steel_ingot"},
        {"default:wood", "default:mese_crystal", "default:wood"},
        {"default:wood", "default:wood", "default:wood"},
    }
})

minetest.register_craft({
    output = "jukebox:bloc_dj",
    recipe = {
        {"default:steel_ingot", "dye:black", "default:steel_ingot"},
        {"dye:black", "default:mese_crystal", "dye:black"},
        {"default:steel_ingot", "dye:black", "default:steel_ingot"},
    }
})

minetest.register_craft({
    output = "jukebox:platine_dj",
    recipe = {
        {"default:steel_ingot", "default:glass", "default:steel_ingot"},
        {"default:steel_ingot", "default:diamond", "default:steel_ingot"},
        {"jukebox:bloc_dj", "dye:black", "jukebox:bloc_dj"},
    }
})

minetest.register_craft({
    output = "jukebox:console_dj",
    recipe = {
        {"default:steel_ingot", "default:glass", "default:steel_ingot"},
        {"default:steel_ingot", "default:mese_crystal", "default:steel_ingot"},
        {"jukebox:bloc_dj", "dye:black", "jukebox:bloc_dj"},
    }
})

local vinyle_crafts = {
    ["jukebox:vinyl1"] = "dye:red",
    ["jukebox:vinyl2"] = "dye:green",
    ["jukebox:vinyl3"] = "dye:yellow",
    ["jukebox:vinyl4"] = "dye:white",
    ["jukebox:vinyl5"] = "dye:blue",
    ["jukebox:vinyl6"] = "dye:cyan",
    ["jukebox:vinyl7"] = "dye:black",
}

local plastic_item = "default:paper"

if minetest.get_modpath("basic_materials") then
    plastic_item = "basic_materials:plastic_sheet"
end

for vinyle_name, dye in pairs(vinyle_crafts) do
    minetest.register_craft({
        output = vinyle_name,
        recipe = {
            {plastic_item,"dye:black", plastic_item},
			{plastic_item, dye, plastic_item},
			{plastic_item, "dye:black", plastic_item}
        }
    })
end

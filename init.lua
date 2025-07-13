local jukebox_sounds = {
    S1 = "song1",
    S2 = "song2",
    S3 = "song3",
}

local Vinyles = {
    ["jukebox:vinyle1"] = "S1;Azizam - EdSheeran",
    ["jukebox:vinyle2"] = "S2;Turrican et Luffy",
    ["jukebox:vinyle3"] = "S3;La Reine Amelaye",
	["jukebox:vinyle4"] = "S4;Musique4",
    ["jukebox:vinyle5"] = "S5;Musique5",
    ["jukebox:vinyle6"] = "S6;Musique6",
	["jukebox:vinyle7"] = "S7;Musique7",
    -- Ajoute d’autres vinyles ici si besoin
}

local jukebox_nodes = {}

local function parse_prefix_title(str)
    if not str then return nil, nil end
    local prefix, title = str:match("^([^;]+);(.+)$")
    if prefix and title then
        return prefix, title
    else
        return nil, nil
    end
end

local function update_infotext(pos)
    local meta = minetest.get_meta(pos)
    local Vinyle = meta:get_string("Vinyle") or ""
    local infotext = "Jukebox"

    local node = minetest.get_node(pos)
    if node.name == "jukebox:platine" then
        infotext = "Platine"
    elseif node.name == "jukebox:jukebox" then
        infotext = "Jukebox"
    elseif node.name == "jukebox:console" then
        infotext = "Console"
    else
        infotext = node.name
    end

    if Vinyle ~= "" then
        infotext = infotext .. "\nVinyle inséré: " .. Vinyle
    else
        infotext = infotext .. "\nAucun Vinyle"
    end

    meta:set_string("infotext", infotext)
end

local function drop_Vinyle(pos, Vinyle_name)
    local node = minetest.get_node(pos)
    local drop_y = 1.5
    if node.name == "jukebox:platine_dj" then
        drop_y = 0.9  
    end
    local drop_pos = {x = pos.x, y = pos.y + drop_y, z = pos.z}
    minetest.add_item(drop_pos, Vinyle_name)
end

local function stop_music(pos, puncher)
    local meta = minetest.get_meta(pos)
    local Vinyle = meta:get_string("Vinyle")
    local handle = meta:get_int("sound_handle")

    if handle and handle ~= 0 then
        minetest.sound_stop(handle)
        minetest.log("action", "[jukebox] Son stoppé à " .. minetest.pos_to_string(pos))
    end

    if puncher and puncher:is_player() and Vinyle ~= "" then
        drop_Vinyle(pos, Vinyle)
        minetest.log("action", "[jukebox] Vinyle droppé au joueur " .. puncher:get_player_name())
    end

    meta:set_string("Vinyle", "")
    meta:set_int("sound_handle", 0)

    local node = minetest.get_node(pos)
    if node.name:find("jukebox:jukebox_active_") then
        minetest.swap_node(pos, { name = "jukebox:jukebox", param2 = node.param2 })
    elseif node.name == "jukebox:platine" then
        -- Platine reste platine, pas de version active
    elseif node.name == "jukebox:platine_dj" then
        -- Platine DJ idem
    else
        minetest.swap_node(pos, { name = "jukebox:jukebox", param2 = node.param2 })
    end

    update_infotext(pos)
end

local playing_sounds = {}

local function play_music(pos, Vinyle_item, sound_name, itemstack)
    local meta = minetest.get_meta(pos)
    local current_handle = meta:get_int("sound_handle")

    -- Si un son est déjà en lecture, stoppe et drop l'ancien Vinyle avant d'en injecter un nouveau
    if current_handle and current_handle ~= 0 then
        minetest.sound_stop(current_handle)

        local old_Vinyle = meta:get_string("Vinyle")
        if old_Vinyle ~= "" and old_Vinyle ~= Vinyle_item then
            drop_Vinyle(pos, old_Vinyle)
        end
    end

    local gain = 0.5
    local max_distance = 10
    minetest.log("action", "[jukebox] Lecture son '" .. sound_name .. "' à " .. minetest.pos_to_string(pos))

    local handle = minetest.sound_play(sound_name, {
        pos = pos,
        gain = gain,
        max_hear_distance = max_distance,
        loop = true,
    })

    if handle then
        meta:set_string("Vinyle", Vinyle_item)
        meta:set_int("sound_handle", handle)
        playing_sounds[minetest.pos_to_string(pos)] = {handle = handle, pos = pos}

        local node = minetest.get_node(pos)
        local new_name = node.name
        if node.name == "jukebox:jukebox" or node.name:find("^jukebox:jukebox_active_") then
            new_name = jukebox_nodes[Vinyle_item] or "jukebox:jukebox"
        end
        minetest.swap_node(pos, {name = new_name, param2 = node.param2})
        itemstack:take_item()
        update_infotext(pos)

        return itemstack
    else
        minetest.log("warning", "[jukebox] Erreur lors de la lecture du son : " .. sound_name)
    end
end



for Vinyle_name, pref_title in pairs(Vinyles) do
    local prefix, title = parse_prefix_title(pref_title)
    if prefix and title then
        minetest.register_craftitem(Vinyle_name, {
            description = "Vinyle : " .. title,
            inventory_image = prefix:lower() .. ".png",
            stack_max = 1,
        })

        local node_name = "jukebox:jukebox_active_" .. prefix
        jukebox_nodes[Vinyle_name] = node_name

        if not minetest.registered_nodes[node_name] then
            minetest.register_node(node_name, {
                description = "Jukebox (Lecture) " .. title,
                drawtype = "nodebox",
                tiles = {
                    "jukebox_top.png^" .. prefix:lower() .. ".png",
                    "default_wood.png",
                    "jukebox_side_lr.png",
                    "jukebox_side_lr.png",
                    "jukebox_side_fb.png",
                    "jukebox_side_fb.png",
                },
                groups = {choppy = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1},
                drop = "jukebox:jukebox",
                paramtype2 = "facedir",
                node_box = {
                    type = "fixed",
                    fixed = {
                        {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}, -- hauteur 1 bloc
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

                on_rightclick = function(pos, node, clicker, itemstack)
                    local held_item = itemstack:get_name()
                    if Vinyles[held_item] then
                        local prefix, _ = parse_prefix_title(Vinyles[held_item])
                        local sound_name = jukebox_sounds[prefix]
                        if sound_name then
                            return play_music(pos, held_item, sound_name, itemstack)
                        end
                    end
                end,

                on_punch = function(pos, node, puncher)
                    stop_music(pos, puncher)
                end,
            })
        end
    else
        minetest.log("warning", "[jukebox] Format invalide pour le Vinyle " .. Vinyle_name)
    end
end

-- Fonction pour formspec de la console DJ
local function get_console_formspec(pos)
	local spos = minetest.pos_to_string(pos)
	return 
		"size[9,10.5]" ..
		default.gui_bg ..
		default.gui_bg_img ..
		default.gui_slots ..
		"background[9,10.5;0,0;console_dj_top.png;false]" ..
		"label[2.5,0;Console DJ]" ..
		"list[nodemeta:" .. spos .. ";storage;3,1;3,3;]" ..
		"list[current_player;main;0.5,6.5;8,4;]" ..
		"listring[nodemeta:" .. spos .. ";storage]" ..
		"listring[current_player;main]" ..
		default.get_hotbar_bg(0.5, 6.5)
end



minetest.register_node("jukebox:jukebox", {
    description = "Jukebox",
    drawtype = "nodebox",
    tiles = {
        "jukebox_top.png",
        "default_wood.png",
        "jukebox_side_lr.png",
        "jukebox_side_lr.png",
        "jukebox_side_fb.png",
        "jukebox_side_fb.png",
    },
    groups = {choppy = 2, oddly_breakable_by_hand = 2},
    paramtype2 = "facedir",
    node_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}, -- hauteur 1 bloc
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

    on_rightclick = function(pos, node, clicker, itemstack)
        local held_item = itemstack:get_name()
        if Vinyles[held_item] then
            local prefix, _ = parse_prefix_title(Vinyles[held_item])
            local sound_name = jukebox_sounds[prefix]
            if sound_name then
                return play_music(pos, held_item, sound_name, itemstack)
            end
        end
    end,

    on_punch = function(pos, node, puncher)
        stop_music(pos, puncher)
    end,
})

minetest.register_node("jukebox:platine", {
    description = "Platine",
    tiles = {
        "platine_top.png",
        "platine_side.png",
        "platine_side.png",
        "platine_side.png",
        "platine_side.png",
        "platine_side_front.png",
    },
    groups = {choppy = 2, oddly_breakable_by_hand = 2},
    paramtype2 = "facedir",
    drawtype = "nodebox",
    node_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}, -- hauteur 1 bloc
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

    on_rightclick = function(pos, node, clicker, itemstack)
        local held_item = itemstack:get_name()
        if Vinyles[held_item] then
            local prefix, _ = parse_prefix_title(Vinyles[held_item])
            local sound_name = jukebox_sounds[prefix]
            if sound_name then
                return play_music(pos, held_item, sound_name, itemstack)
            end
        end
    end,

    on_punch = function(pos, node, puncher)
        stop_music(pos, puncher)
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

    on_rightclick = function(pos, node, clicker, itemstack)
        local held_item = itemstack:get_name()
        if Vinyles[held_item] then
            local prefix, _ = parse_prefix_title(Vinyles[held_item])
            local sound_name = jukebox_sounds[prefix]
            if sound_name then
                return play_music(pos, held_item, sound_name, itemstack)
            end
        end
    end,

    on_punch = function(pos, node, puncher)
        stop_music(pos, puncher)
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
    ["jukebox:vinyle1"] = "dye:red",
    ["jukebox:vinyle2"] = "dye:green",
    ["jukebox:vinyle3"] = "dye:yellow",
    ["jukebox:vinyle4"] = "dye:white",
    ["jukebox:vinyle5"] = "dye:blue",
    ["jukebox:vinyle6"] = "dye:cyan",
    ["jukebox:vinyle7"] = "dye:black",
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


local function get_all_jukebox_nodes()
    local nodes = {}
    for nodename, def in pairs(minetest.registered_nodes) do
        if nodename:sub(1,8) == "jukebox:" then
            table.insert(nodes, nodename)
        end
    end
    return nodes
end

minetest.register_lbm({
    name = "jukebox:resume_music",
    nodenames = get_all_jukebox_nodes(),
    run_at_every_load = true,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        local Vinyle = meta:get_string("Vinyle")
        if Vinyle == nil or Vinyle == "" then
            return -- Pas de Vinyle, rien à faire
        end

        local prefix, _ = parse_prefix_title(Vinyles[Vinyle] or "")
        if not prefix then
            return -- Vinyle mal formaté ou inconnu
        end

        local sound_name = jukebox_sounds[prefix]
        if not sound_name then
            return -- Son non trouvé pour ce Vinyle
        end

        local handle = meta:get_int("sound_handle")
        if handle and handle ~= 0 then
            minetest.sound_stop(handle) -- Au cas où il y aurait un son déjà en cours
        end

        local new_handle = minetest.sound_play(sound_name, {
            pos = pos,
            gain = 0.5,
            max_hear_distance = 10,
            loop = true,
        })

        if new_handle then
            meta:set_int("sound_handle", new_handle)
            update_infotext(pos)
        end
    end,
})

local last_texture_index = nil

local function spawn_music_particles(pos, node)
    local vx = math.random(-0.1, 0.1) / 2 -- variation horizontale
    local vz = math.random(-0.1, 0.1) / 2
    local vy = 0.2  -- légère montée

    -- Ajuster la hauteur de spawn selon le node
    local base_y = 0.7
    if node.name == "jukebox:platine_dj" then
        base_y = 0.1
    end

    local textures = {"note1.png", "note2.png", "note3.png", "note4.png", "note5.png", "note6.png", "note7.png", "note8.png", "note9.png"}
    
	local texture_index
    repeat
        texture_index = math.random(#textures)
    until texture_index ~= last_texture_index

    last_texture_index = texture_index
    local texture = textures[texture_index]


    minetest.add_particle({
        pos = {
            x = pos.x + math.random() * 0.8 - 0.2,
            y = pos.y + base_y,
            z = pos.z + math.random() * 0.8 - 0.2,
        },
        velocity = {x = vx, y = vy, z = vz},
        acceleration = {x = 0, y = 1, z = 0},
        expirationtime = 1.5,
        size = 5,
        collisiondetection = true,
        collision_removal = false,
        texture = texture,
        glow = 15,
    })
end

minetest.register_abm({
    label = "Jukebox music particles",
    nodenames = get_all_jukebox_nodes(),
    interval = 0.3,
    chance = 1,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        local Vinyle = meta:get_string("Vinyle")
        local handle = meta:get_int("sound_handle")
        if Vinyle ~= "" and handle and handle ~= 0 then
            spawn_music_particles(pos, node)
        end
    end,
})

local playing_sounds = {}

-- Commande pour stopper toutes les musiques
minetest.register_chatcommand("jukebox_stop_music", {
    description = "Arrête toutes les musiques en cours",
    privs = {interact = true},
    func = function(name)
        for key, entry in pairs(playing_sounds) do
            if entry.handle and entry.handle ~= 0 then
                minetest.sound_stop(entry.handle)
                local pos = entry.pos
                if pos then
                    local meta = minetest.get_meta(pos)
                    local Vinyle = meta:get_string("Vinyle")
                    if Vinyle and Vinyle ~= "" then
                        drop_Vinyle(pos, Vinyle)
                    end
                    meta:set_string("Vinyle", "")
                    meta:set_int("sound_handle", 0)
                    local node = minetest.get_node(pos)
                    minetest.swap_node(pos, {name = "jukebox:jukebox", param2 = node.param2})
                    update_infotext(pos)
                end
            end
        end
        playing_sounds = {}
        return true, "Toutes les musiques ont été arrêtées."
    end,
})

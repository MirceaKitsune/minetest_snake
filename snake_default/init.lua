-- Snake mod by MirceaKitsune
snake_default = {}

-- Helper for adding a node list multiple times to a layer
function layer_add(layer, count, nodes)
	for i = 1, count do
		table.insert(layer, nodes)
	end
end

-- Shape definitions
local nodes_body_head = snake.draw.add({
	snake.draw.round({"snake_default:snake_body"}, {x = 0, y = 0, z = 0}, 5, 0.25),
	snake.draw.round({"snake_default:snake_body"}, {x = 0, y = -2, z = 5}, 2, 0.25), -- Nose
	snake.draw.round({"snake_default:snake_body"}, {x = -4, y = 4, z = 0}, 2, 0.25), -- Ear left
	snake.draw.round({"snake_default:snake_body"}, {x = 4, y = 4, z = 0}, 2, 0.25), -- Ear right
})
local nodes_body_segment = snake.draw.add({
	snake.draw.round({"snake_default:snake_body"}, {x = 0, y = -1, z = 0}, 4, 0.25),
})
local nodes_body_tail = snake.draw.add({
	snake.draw.round({"snake_default:snake_body"}, {x = 0, y = -2, z = 0}, 3, 0.25),
})
local nodes_flesh_head = snake.draw.add({
	snake.draw.round({"snake_default:snake_flesh"}, {x = 0, y = 0, z = 0}, 4, 0.25),
})
local nodes_flesh_segment = snake.draw.add({
	snake.draw.round({"snake_default:snake_flesh"}, {x = 0, y = -1, z = 0}, 3, 0.25),
})
local nodes_air_head = snake.draw.add({
	snake.draw.round({"air"}, {x = 0, y = 0, z = 0}, 3, 0.125),
})
local nodes_air_segment = snake.draw.add({
	snake.draw.round({"air"}, {x = 0, y = -1, z = 0}, 2, 0.125),
})
local nodes_detail_head = snake.draw.add({
	snake.draw.fill({"snake_default:snake_flesh"}, {x = 0, y = 1, z = 0}, {x = 0, y = 3, z = 0}), -- Heart string
	snake.draw.single({"snake_default:snake_eye"}, {x = -2, y = 0, z = 5}), -- Eye left
	snake.draw.single({"snake_default:snake_eye"}, {x = 2, y = 0, z = 5}), -- Eye right
	snake.draw.single({"snake_default:snake_bone"}, {x = -1, y = -3, z = 4}), -- Tooth back left
	snake.draw.single({"snake_default:snake_bone"}, {x = 1, y = -3, z = 4}), -- Tooth back right
	snake.draw.single({"snake_default:snake_bone"}, {x = -1, y = -4, z = 5}), -- Tooth front left
	snake.draw.single({"snake_default:snake_bone"}, {x = 1, y = -4, z = 5}), -- Tooth front right
	snake.draw.round({"air"}, {x = 0, y = -3, z = 3}, 1, 0.5), -- Mouth back
	snake.draw.round({"air"}, {x = 0, y = -4, z = 6}, 1, 0.5), -- Mouth front
})

-- Layer definitions
local layer_body = {}
local layer_flesh = {}
local layer_air = {}
local layer_detail = {}
layer_add(layer_body, 1, nodes_body_head)
layer_add(layer_body, 12, nodes_body_segment)
layer_add(layer_body, 3, nodes_body_tail)
layer_add(layer_flesh, 1, nodes_flesh_head)
layer_add(layer_flesh, 12, nodes_flesh_segment)
layer_add(layer_air, 1, nodes_air_head)
layer_add(layer_air, 12, nodes_air_segment)
layer_add(layer_detail, 1, nodes_detail_head)

snake.register_node("snake_default:snake_body", {
	description = "Snake body",
	tiles = {"snake_default_body.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, choppy = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
})

snake.register_node("snake_default:snake_eye", {
	description = "Snake eye",
	tiles = {"snake_default_eye.png", "snake_default_eye.png", "snake_default_eye.png", "snake_default_eye.png", "snake_default_eye.png", "snake_default_eye_0.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, choppy = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
})

snake.register_node("snake_default:snake_bone", {
	description = "Snake bone",
	tiles = {"snake_default_bone.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, crumbly = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_stone_defaults(),
})

snake.register_node("snake_default:snake_flesh", {
	description = "Snake flesh",
	tiles = {{
		image = "snake_default_flesh.png",
		backface_culling = true,
		animation = {
			type = "vertical_frames",
			aspect_w = 16,
			aspect_h = 16,
			length = 2.5,
		},
	}},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, choppy = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
})

snake.register_root("snake_default:snake_heart", {
	description = "Snake heart",
	tiles = {{
		image = "snake_default_heart.png",
		backface_culling = true,
		animation = {
			type = "vertical_frames",
			aspect_w = 16,
			aspect_h = 16,
			length = 2,
		},
	}},
	paramtype2 = "facedir",
	drawtype = "normal",
	light_source = 12,
	groups = {fleshy = 1, choppy = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_stone_defaults(),

	layers = {layer_body, layer_flesh, layer_air, layer_detail},
	radius = 6,
	time_min = 1,
	time_max = 1,
	lod = 64,
	chance_path = 0.1,
	chance_move = 0.9,
	chance_look = 0.25,
	position_eye = {x = 0, y = -4, z = 8},
	height = 5,
	sight_min = 16,
	sight_max = 64,
	goal_climb = 16,
	nodes_clear = {"air"},
	nodes_moves = {"group:snappy", "group:attached_node"},
	nodes_goal = {"default:meselamp"},
	nodes_goal_wield = {"default:meselamp"},
})

snake.register_egg("snake_default:snake_egg", {
	description = "Snake egg",
	tiles = {"snake_default_bone.png"},
	paramtype = "light",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.375, -0.5, -0.375, 0.375, 0.5, 0.375},
		},
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.375, -0.5, -0.375, 0.375, 0.5, 0.375},
		},
	},
	groups = {fleshy = 1, crumbly = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_stone_defaults(),

	nodes_root = {"snake_default:snake_heart"},
	time_min = 5,
	time_max = 10,
})

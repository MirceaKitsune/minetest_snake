-- Snake mod by MirceaKitsune
snake_default = {}

-- Helper for repeating a shape inside an area for a shape group, loops from the shape's position to the given offset
function shape_area(shapes, shape, offset)
	for _, x in offset.x do
		for _, y in offset.y do
			for _, z in offset.z do
				s = table.copy(shape)
				s.position = vector.add(shape.position, vector.new(x, y, z))
				table.insert(shapes, s)
			end
		end
	end
end

-- Helper for adding a shape group multiple times to a layer
function layer_add(layer, count, shape)
	for i = 1, count do
		table.insert(layer, shape)
	end
end

-- Shape definitions
local shapes_body_head = {
	{nodes = {"snake_default:snake_body"}, position = {x = 0, y = 0, z = 0}, radius = 5, roundness = 0.25},
	{nodes = {"snake_default:snake_body"}, position = {x = 0, y = -2, z = 5}, radius = 2, roundness = 0.25}, -- Nose
	{nodes = {"snake_default:snake_body"}, position = {x = -4, y = 4, z = 0}, radius = 2, roundness = 0.25}, -- Ear, left
	{nodes = {"snake_default:snake_body"}, position = {x = 4, y = 4, z = 0}, radius = 2, roundness = 0.25}, -- Ear, right
}
local shapes_body_segment = {
	{nodes = {"snake_default:snake_body"}, position = {x = 0, y = -1, z = 0}, radius = 4, roundness = 0.25},
}
local shapes_body_tail = {
	{nodes = {"snake_default:snake_body"}, position = {x = 0, y = -2, z = 0}, radius = 3, roundness = 0.25},
}
local shapes_flesh_head = {
	{nodes = {"snake_default:snake_flesh"}, position = {x = 0, y = 0, z = 0}, radius = 4, roundness = 0.25},
}
local shapes_flesh_segment = {
	{nodes = {"snake_default:snake_flesh"}, position = {x = 0, y = -1, z = 0}, radius = 3, roundness = 0.25},
}
local shapes_air_head = {
	{nodes = {"air"}, position = {x = 0, y = 0, z = 0}, radius = 3, roundness = 0.125},
	{nodes = {"air"}, position = {x = 0, y = -3, z = 3}, radius = 1, roundness = 0.5}, -- Mouth 1
	{nodes = {"air"}, position = {x = 0, y = -4, z = 6}, radius = 1, roundness = 0.5}, -- Mouth 2
}
local shapes_air_segment = {
	{nodes = {"air"}, position = {x = 0, y = -1, z = 0}, radius = 2, roundness = 0.125},
}

-- Layer definitions
local layer_body = {}
local layer_flesh = {}
local layer_air = {}
layer_add(layer_body, 1, shapes_body_head)
layer_add(layer_body, 12, shapes_body_segment)
layer_add(layer_body, 3, shapes_body_tail)
layer_add(layer_flesh, 1, shapes_flesh_head)
layer_add(layer_flesh, 12, shapes_flesh_segment)
layer_add(layer_air, 1, shapes_air_head)
layer_add(layer_air, 12, shapes_air_segment)

snake.register_node("snake_default:snake_flesh", false, {
	description = "Snake flesh",
	tiles = {"default_silver_sand.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	light_source = 0,
	waving = 0,
	groups = {not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
})

snake.register_node("snake_default:snake_body", false, {
	description = "Snake body",
	tiles = {"default_silver_sandstone_brick.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	light_source = 0,
	waving = 0,
	groups = {not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
})

snake.register_node("snake_default:snake_heart", true, {
	description = "Snake heart",
	tiles = {
		"default_furnace_top.png", "default_furnace_bottom.png",
		"default_furnace_side.png", "default_furnace_side.png",
		"default_furnace_side.png", "default_furnace_front.png"
	},
	paramtype2 = "facedir",
	drawtype = "normal",
	light_source = 12,
	waving = 0,
	groups = {oddly_breakable_by_hand = 1},
	sounds = default.node_sound_stone_defaults(),

	layers = {layer_body, layer_flesh, layer_air},
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
	nodes_moves = {"group:choppy", "group:snappy", "group:attached_node"},
	nodes_goal = {"default:meselamp"},
	nodes_goal_wield = {"default:meselamp"},
})

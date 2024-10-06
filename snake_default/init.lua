-- Snake mod by MirceaKitsune
snake_default = {}

-- Returns the list of sphere positions for the given radius and hardness centered around a position
function position_get_sphere(name, pos, radius, hardness)
	local nodes = {}
	for x = pos.x - radius, pos.x + radius do
		for y = pos.y - radius, pos.y + radius do
			for z = pos.z - radius, pos.z + radius do
				local p = vector.new(x, y, z)
				if hardness >= 1 or vector.distance(pos, p) <= radius * (1 + hardness) then
					table.insert(nodes, {x = p.x, y = p.y, z = p.z, name = name})
				end
			end
		end
	end
	return nodes
end

-- Returns a combined list of nodes removing duplicates
function nodes_get_mixed(list)
	local nodes_hash = {}
	local nodes = {}
	for _, nodes_list in ipairs(list) do
		for _, n in ipairs(nodes_list) do
			local hash = minetest.hash_node_position(n)
			if nodes_hash[hash] == nil then
				nodes_hash[hash] = n.name
				table.insert(nodes, {x = n.x, y = n.y, z = n.z, name = n.name})
			end
		end
	end
	return nodes
end

-- Helper for adding a node list multiple times to a layer
function layer_add(layer, count, nodes)
	for i = 1, count do
		table.insert(layer, nodes)
	end
end

-- Shape definitions
local nodes_body_head = nodes_get_mixed({
	position_get_sphere({"snake_default:snake_body"}, {x = 0, y = 0, z = 0}, 5, 0.25),
	position_get_sphere({"snake_default:snake_body"}, {x = 0, y = -2, z = 5}, 2, 0.25), -- Nose
	position_get_sphere({"snake_default:snake_body"}, {x = -4, y = 4, z = 0}, 2, 0.25), -- Ear, left
	position_get_sphere({"snake_default:snake_body"}, {x = 4, y = 4, z = 0}, 2, 0.25), -- Ear, right
})
local nodes_body_segment = nodes_get_mixed({
	position_get_sphere({"snake_default:snake_body"}, {x = 0, y = -1, z = 0}, 4, 0.25),
})
local nodes_body_tail = nodes_get_mixed({
	position_get_sphere({"snake_default:snake_body"}, {x = 0, y = -2, z = 0}, 3, 0.25),
})
local nodes_flesh_head = nodes_get_mixed({
	position_get_sphere({"snake_default:snake_flesh"}, {x = 0, y = 0, z = 0}, 4, 0.25),
})
local nodes_flesh_segment = nodes_get_mixed({
	position_get_sphere({"snake_default:snake_flesh"}, {x = 0, y = -1, z = 0}, 3, 0.25),
})
local nodes_air_head = nodes_get_mixed({
	position_get_sphere({"air"}, {x = 0, y = 0, z = 0}, 3, 0.125),
	position_get_sphere({"air"}, {x = 0, y = -3, z = 3}, 1, 0.5), -- Mouth 1
	position_get_sphere({"air"}, {x = 0, y = -4, z = 6}, 1, 0.5), -- Mouth 2
})
local nodes_air_segment = nodes_get_mixed({
	position_get_sphere({"air"}, {x = 0, y = -1, z = 0}, 2, 0.125),
})

-- Layer definitions
local layer_body = {}
local layer_flesh = {}
local layer_air = {}
layer_add(layer_body, 1, nodes_body_head)
layer_add(layer_body, 12, nodes_body_segment)
layer_add(layer_body, 3, nodes_body_tail)
layer_add(layer_flesh, 1, nodes_flesh_head)
layer_add(layer_flesh, 12, nodes_flesh_segment)
layer_add(layer_air, 1, nodes_air_head)
layer_add(layer_air, 12, nodes_air_segment)

snake.register_node("snake_default:snake_flesh", {
	description = "Snake flesh",
	tiles = {"default_silver_sand.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	light_source = 0,
	waving = 0,
	groups = {not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
})

snake.register_node("snake_default:snake_body", {
	description = "Snake body",
	tiles = {"default_silver_sandstone_brick.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	light_source = 0,
	waving = 0,
	groups = {not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
})

snake.register_root("snake_default:snake_heart", {
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

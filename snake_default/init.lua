-- Snake mod by MirceaKitsune
snake_default = {
	timer_min = 5,
	timer_max = 10,
	chance_expire = 0.1,
	damage_on_heal = -0.001,
	damage_on_rot = 0.0005,
	damage_dig_healthy = 0.05,
	damage_dig_rotten = 0.1,
}

-- Helper: Add a node list multiple times to a layer
function snake_default.layer_add(layer, count, nodes)
	for i = 1, count do
		table.insert(layer, nodes)
	end
end

-- Helper: Get the health of the root node for pos
function snake_default.node_health_get(pos, amount)
	local root_pos = vector.from_string(core.get_meta(pos):get_string("root"))
	if root_pos then
		local root_meta = core.get_meta(root_pos)
		if root_meta and root_meta:contains("health") then
			return root_meta:get_float("health")
		end
	end
	return 0
end

-- Helper: Set the health of the root node for pos
function snake_default.node_health_set(pos, amount)
	local root_pos = vector.from_string(core.get_meta(pos):get_string("root"))
	if root_pos then
		local root_meta = core.get_meta(root_pos)
		if root_meta and root_meta:contains("health") then
			root_meta:set_float("health", math.max(0, math.min(1, root_meta:get_float("health") + amount)))
			root_meta:set_string("infotext", tostring(root_meta:get_float("health")))
		end
	end
end

-- Helper: Change nodes to a new name
function snake_default.node_change_swap(pos, name)
	local node = core.get_node(pos)
	core.swap_node(pos, {name = name, param2 = node.param2})
	core.registered_nodes[name].on_construct(pos)
end

-- Helper: Change nodes based on a suffix
function snake_default.node_change_suffix(pos, suffix)
	local node = core.get_node(pos)
	local name = string.sub(node.name, -#suffix, -1) == suffix and string.sub(node.name, 1, -#suffix - 1) or node.name .. suffix
	core.swap_node(pos, {name = name, param2 = node.param2})
	core.registered_nodes[name].on_construct(pos)
end

-- On construct: Start node timer
function snake_default.on_construct_timer(pos)
	core.get_node_timer(pos):start(0)
end

-- On destruct: Stop node timer
function snake_default.on_destruct_timer(pos)
	core.get_node_timer(pos):stop()
end

-- Healthy flesh, On dig: Apply damage and switch to rotten variant
function snake_default.flesh_healthy_dig(pos, node, digger)
	snake_default.node_health_set(pos, -snake_default.damage_dig_healthy)
	snake_default.node_change_suffix(pos, "_rotten")
end

-- Healthy flesh, On timer: Apply healing and switch to rotten variant based on health
function snake_default.flesh_healthy_timer(pos)
	local timer = snake_default.timer_min + math.random() * (snake_default.timer_max - snake_default.timer_min)
	core.get_node_timer(pos):start(timer)

	if snake_default.node_health_get(pos) < math.random() then
		snake_default.node_health_set(pos, -snake_default.damage_on_rot)
		snake_default.node_change_suffix(pos, "_rotten")
	end
end

-- Rotten flesh, On dig: Apply damage and switch to blood source
function snake_default.flesh_rotten_dig(pos, node, digger)
	snake_default.node_health_set(pos, -snake_default.damage_dig_rotten)
	snake_default.node_change_swap(pos, "snake_default:snake_blood_source")
end

-- Rotten flesh, On timer: Apply healing and switch to healthy variant based on health or clear self if health is 0
function snake_default.flesh_rotten_timer(pos)
	local timer = snake_default.timer_min + math.random() * (snake_default.timer_max - snake_default.timer_min)
	core.get_node_timer(pos):start(timer)

	if snake_default.node_health_get(pos) <= 0 then
		if snake_default.chance_expire > math.random() then
			core.remove_node(pos)
			core.get_node_timer(pos):stop()
		end
	elseif snake_default.node_health_get(pos) > math.random() then
		snake_default.node_health_set(pos, -snake_default.damage_on_heal)
		snake_default.node_change_suffix(pos, "_rotten")
	end
end

-- Blood, On construct: Start node timer
function snake_default.blood_construct(pos)
	local timer = snake_default.timer_min + math.random() * (snake_default.timer_max - snake_default.timer_min)
	core.get_node_timer(pos):start(timer)
end

-- Blood, On destruct: Stop node timer
function snake_default.blood_destruct(pos)
	core.get_node_timer(pos):stop()
end

-- Blood, On timer: Remove self
function snake_default.blood_timer(pos)
	core.remove_node(pos)
end

-- Shape definitions
snake_default.nodes_body_head = snake.draw.add({
	snake.draw.round({"snake_default:snake_body"}, {x = 0, y = 0, z = 0}, 5, 0.25),
	snake.draw.round({"snake_default:snake_body"}, {x = 0, y = -2, z = 5}, 2, 0.25), -- Nose
	snake.draw.round({"snake_default:snake_body"}, {x = -4, y = 4, z = 0}, 2, 0.25), -- Ear left
	snake.draw.round({"snake_default:snake_body"}, {x = 4, y = 4, z = 0}, 2, 0.25), -- Ear right
})
snake_default.nodes_body_segment = snake.draw.add({
	snake.draw.round({"snake_default:snake_body"}, {x = 0, y = -1, z = 0}, 4, 0.25),
})
snake_default.nodes_body_tail = snake.draw.add({
	snake.draw.round({"snake_default:snake_body"}, {x = 0, y = -2, z = 0}, 3, 0.25),
})
snake_default.nodes_flesh_head = snake.draw.add({
	snake.draw.round({"snake_default:snake_flesh"}, {x = 0, y = 0, z = 0}, 4, 0.25),
})
snake_default.nodes_flesh_segment = snake.draw.add({
	snake.draw.round({"snake_default:snake_flesh"}, {x = 0, y = -1, z = 0}, 3, 0.25),
})
snake_default.nodes_air_head = snake.draw.add({
	snake.draw.round({"air"}, {x = 0, y = 0, z = 0}, 3, 0.125),
})
snake_default.nodes_air_segment = snake.draw.add({
	snake.draw.round({"air"}, {x = 0, y = -1, z = 0}, 2, 0.125),
})
snake_default.nodes_detail_head = snake.draw.add({
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
snake_default.layer_body = {}
snake_default.layer_flesh = {}
snake_default.layer_air = {}
snake_default.layer_detail = {}
snake_default.layer_add(snake_default.layer_body, 1, snake_default.nodes_body_head)
snake_default.layer_add(snake_default.layer_body, 12, snake_default.nodes_body_segment)
snake_default.layer_add(snake_default.layer_body, 3, snake_default.nodes_body_tail)
snake_default.layer_add(snake_default.layer_flesh, 1, snake_default.nodes_flesh_head)
snake_default.layer_add(snake_default.layer_flesh, 12, snake_default.nodes_flesh_segment)
snake_default.layer_add(snake_default.layer_air, 1, snake_default.nodes_air_head)
snake_default.layer_add(snake_default.layer_air, 12, snake_default.nodes_air_segment)
snake_default.layer_add(snake_default.layer_detail, 1, snake_default.nodes_detail_head)

core.register_node("snake_default:snake_blood_source", {
	description = "Snake blood source",
	drawtype = "liquid",
	waving = 3,
	tiles = {
		{
			name = "snake_default_blood_source_animated.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 2,
			},
		},
		{
			name = "snake_default_blood_source_animated.png",
			backface_culling = true,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 2,
			},
		},
	},
	use_texture_alpha = "opaque",
	paramtype = "light",
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	is_ground_content = false,
	drop = "",
	drowning = 1,
	liquidtype = "source",
	liquid_alternative_flowing = "snake_default:snake_blood_flowing",
	liquid_alternative_source = "snake_default:snake_blood_source",
	liquid_viscosity = 1,
	post_effect_color = {r = 127, g = 15, b = 15, a = 127},
	groups = {water = 3, liquid = 3, cools_lava = 1},
	sounds = default.node_sound_water_defaults(),
	on_construct = snake_default.blood_construct,
	on_destruct = snake_default.blood_destruct,
	on_timer = snake_default.blood_timer,
})

core.register_node("snake_default:snake_blood_flowing", {
	description = "Flowing snake blood",
	drawtype = "flowingliquid",
	waving = 3,
	tiles = {"snake_default_blood.png"},
	special_tiles = {
		{
			name = "snake_default_blood_flowing_animated.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 0.5,
			},
		},
		{
			name = "snake_default_blood_flowing_animated.png",
			backface_culling = true,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 0.5,
			},
		},
	},
	use_texture_alpha = "opaque",
	paramtype = "light",
	paramtype2 = "flowingliquid",
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	is_ground_content = false,
	drop = "",
	drowning = 1,
	liquidtype = "flowing",
	liquid_alternative_flowing = "snake_default:snake_blood_flowing",
	liquid_alternative_source = "snake_default:snake_blood_source",
	liquid_viscosity = 1,
	post_effect_color = {r = 127, g = 15, b = 15, a = 127},
	groups = {water = 3, liquid = 3, not_in_creative_inventory = 1, cools_lava = 1},
	sounds = default.node_sound_water_defaults(),
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
	on_construct = snake_default.on_construct_timer,
	on_destruct = snake_default.on_destruct_timer,
	on_dig = snake_default.flesh_healthy_dig,
	on_timer = snake_default.flesh_healthy_timer,
})

snake.register_node("snake_default:snake_flesh_rotten", {
	description = "Snake flesh rotten",
	tiles = {"snake_default_flesh_rotten.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, choppy = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
	on_construct = snake_default.on_construct_timer,
	on_destruct = snake_default.on_destruct_timer,
	on_dig = snake_default.flesh_rotten_dig,
	on_timer = snake_default.flesh_rotten_timer,
})

snake.register_node("snake_default:snake_body", {
	description = "Snake body",
	tiles = {"snake_default_body.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, choppy = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
	on_construct = snake_default.on_construct_timer,
	on_destruct = snake_default.on_destruct_timer,
	on_dig = snake_default.flesh_healthy_dig,
	on_timer = snake_default.flesh_healthy_timer,
})

snake.register_node("snake_default:snake_body_rotten", {
	description = "Snake body rotten",
	tiles = {"snake_default_body_rotten.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, choppy = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
	on_construct = snake_default.on_construct_timer,
	on_destruct = snake_default.on_destruct_timer,
	on_dig = snake_default.flesh_rotten_dig,
	on_timer = snake_default.flesh_rotten_timer,
})

snake.register_node("snake_default:snake_eye", {
	description = "Snake eye",
	tiles = {"snake_default_eye.png", "snake_default_eye.png", "snake_default_eye.png", "snake_default_eye.png", "snake_default_eye.png", "snake_default_eye_0.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, choppy = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
	on_construct = snake_default.on_construct_timer,
	on_destruct = snake_default.on_destruct_timer,
	on_dig = snake_default.flesh_healthy_dig,
	on_timer = snake_default.flesh_healthy_timer,
})

snake.register_node("snake_default:snake_eye_rotten", {
	description = "Snake eye rotten",
	tiles = {"snake_default_eye.png", "snake_default_eye.png", "snake_default_eye.png", "snake_default_eye.png", "snake_default_eye.png", "snake_default_eye_rotten.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, choppy = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
	on_construct = snake_default.on_construct_timer,
	on_destruct = snake_default.on_destruct_timer,
	on_dig = snake_default.flesh_rotten_dig,
	on_timer = snake_default.flesh_rotten_timer,
})

snake.register_node("snake_default:snake_bone", {
	description = "Snake bone",
	tiles = {"snake_default_bone.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	groups = {fleshy = 1, crumbly = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_stone_defaults(),
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

	layers = {snake_default.layer_body, snake_default.layer_flesh, snake_default.layer_air, snake_default.layer_detail},
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
	nodes_moves = {"default:chest", "default:chest_locked", "default:chest_open", "default:chest_locked_open", "default:furnace", "default:furnace_active", "group:attached_node"},
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

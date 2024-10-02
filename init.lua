-- Snake mod by MirceaKitsune
snake = {}

local INTERVAL = 10 -- Interval

-- Push entities located at a specific position if the node we're pushing to is clear
function snake:push(pos, dir)
	local objects = minetest.get_objects_inside_radius(pos, 1)
	if #objects > 0 then
		local pos_new = {x = pos.x + dir.x, y = pos.y + dir.y, z = pos.z + dir.z}
		if minetest.get_node(pos_new).name == "air" then
			for i, obj in pairs(objects) do
				local obj_pos = obj.get_pos(obj)
				local obj_pos_new = {x = obj_pos.x + dir.x, y = obj_pos.y + dir.y, z = obj_pos.z + dir.z}
				obj.move_to(obj, obj_pos_new)
			end
		end
	end
end

-- Handles clearing or replacing a specific node while setting its proper facing direction
function snake:move_set_at(pos, dir, name)
	if not name then
		minetest.remove_node(pos)
	else
		local node = minetest.get_node(pos)
		local node_param2 = dir and minetest.dir_to_facedir({x = -dir.x, y = -dir.y, z = -dir.z}, true) or node.param2
		if node.name ~= name or node.param2 ~= node_param2 then
			minetest.set_node(pos, { name = name, param2 = node_param2 })
		end
	end
end

-- Preforms a move in the given direction
-- The chain of nodes making up the snake is stored in meta as an array of node positions
function snake:move_set(pos, dir)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local def = minetest.registered_nodes[node.name]

	local pos_up = {x = pos.x, y = pos.y + 1, z = pos.z}
	local pos_new = {x = pos.x + dir.x, y = pos.y + dir.y, z = pos.z + dir.z}
	local meta_new = minetest.get_meta(pos_new)

	-- Push any entity that's blocking the new position or sitting on top of the head
	snake:push(pos_new, dir)
	snake:push(pos_up, dir)

	-- Get relevant variables from metadata
	local chain = minetest.deserialize(meta:get_string("chain")) or { pos }
	local length = meta:get_int("length")
	if length == 0 then
		length = math.random(def.length_min, def.length_max)
	end

	-- Index 1: Previous tail, will be removed
	-- Index 2: Penultimate body, becomes the new tail
	-- Index last: New position, becomes the head
	-- Index last - 1: Previous head, becomes body or tail
	table.insert(chain, pos_new)
	for i, pos in pairs(chain) do
		if i == #chain then
			snake:move_set_at(pos, dir, node.name) -- Head
		elseif i < #chain and i > #chain - length then
			snake:move_set_at(pos, nil, def.node_body) -- Body
		elseif i == #chain - length then
			snake:move_set_at(pos, nil, def.node_tail) -- Tail
		else
			snake:move_set_at(pos, nil, nil) -- Clear
		end
	end

	-- Trim the chain to remove entries below the new position of the tail
	while #chain > length + 1 do
		table.remove(chain, 1)
	end

	-- Copy relevant metadata properties from the previous node
	meta_new:set_string("chain", minetest.serialize(chain))
	meta_new:set_int("length", length)

	-- Preform an instant update until the snake is at full length, afterward set the timer to a standard value
	if #chain < length + 1 then
		minetest.get_node_timer(pos_new):stop()
		snake:move(pos_new)
	else
		local timer = def.tick + (length * def.tick_length)
		minetest.get_node_timer(pos_new):start(timer)
	end
end

-- Look for a valid direction the head can move to, if found the move is then preformed
function snake:move(pos)
	-- If the snake can fall, it will automatically do so and skip looking for horizontal positions
	-- If the snake has at least two solid neighbors (own body counted) it can attempt to climb up
	local dst = {}
	if minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name == "air" then
		table.insert(dst, {x = 0, y = -1, z = 0})
	else
		if minetest.get_node({x = pos.x - 1, y = pos.y, z = pos.z}).name == "air" then
			table.insert(dst, {x = -1, y = 0, z = 0})
		end
		if minetest.get_node({x = pos.x + 1, y = pos.y, z = pos.z}).name == "air" then
			table.insert(dst, {x = 1, y = 0, z = 0})
		end
		if minetest.get_node({x = pos.x, y = pos.y, z = pos.z - 1}).name == "air" then
			table.insert(dst, {x = 0, y = 0, z = -1})
		end
		if minetest.get_node({x = pos.x, y = pos.y, z = pos.z + 1}).name == "air" then
			table.insert(dst, {x = 0, y = 0, z = 1})
		end
		if #dst < 3 and minetest.get_node({x = pos.x, y = pos.y + 1, z = pos.z}).name == "air" then
			table.insert(dst, {x = 0, y = 1, z = 0})
		end
	end

	if #dst > 0 then
		local dir = dst[math.random(1, #dst)]
		snake:move_set(pos, dir)
	end
end

timer = function (pos)
	snake:move(pos)
end

construct = function (pos)
	minetest.get_node_timer(pos):start(0)
end

destruct = function (pos)
	minetest.get_node_timer(pos):stop()
end

minetest.register_node("snake:snake_head", {
	description = "Snake head",
	tiles = {
		"default_furnace_top.png", "default_furnace_bottom.png",
		"default_furnace_side.png", "default_furnace_side.png",
		"default_furnace_side.png", "default_furnace_front.png"
	},
	paramtype2 = "facedir",
	drawtype = "liquid",
	waving = 3,
	groups = {cracky = 2, stone = 2},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),

	node_body = "snake:snake_body",
	node_tail = "snake:snake_tail",
	length_min = 1,
	length_max = 10,
	tick = 1.0,
	tick_length = 0.125,

	on_timer = timer,
	on_construct = construct,
	on_destruct = destruct,
	on_blast = destruct,
})

minetest.register_node("snake:snake_body", {
	description = "Snake body",
	tiles = {"default_cobble.png"},
	paramtype2 = "facedir",
	drawtype = "liquid",
	waving = 3,
	is_ground_content = false,
	groups = {cracky = 2, stone = 2},
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("snake:snake_tail", {
	description = "Snake tail",
	tiles = {"default_mossycobble.png"},
	paramtype2 = "facedir",
	drawtype = "liquid",
	waving = 3,
	is_ground_content = false,
	groups = {cracky = 2, stone = 2},
	sounds = default.node_sound_stone_defaults(),
})

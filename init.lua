-- Snake mod by MirceaKitsune
snake = {}

-- Generates and returns the list of sphere positions for the given radius and hardness centered around the given position
-- Each sphere shape is generated once and cached to avoid recalculating it per call
positions_cache_sphere = {}
positions_get_sphere = function(pos, radius, hardness)
	local i = minetest.serialize({radius, hardness})
	if positions_cache_sphere[i] == nil then
		positions_cache_sphere[i] = {}
		if radius > 0 then
			for x = -radius, radius do
				for y = -radius, radius do
					for z = -radius, radius do
						local pos = {x = x, y = y, z = z}
						if vector.distance(pos, vector.zero()) <= radius * (1 + hardness) then
							table.insert(positions_cache_sphere[i], pos)
						end
					end
				end
			end
		end
	end

	local positions = {}
	for _, p in pairs(positions_cache_sphere[i]) do
		table.insert(positions, vector.add(p, pos))
	end
	return positions
end

-- If a list of names is provided each position is checked for nodes with that name or in that group, if the objects flag is set each position is searched for entities
-- Search positions only need to contain a position in the format {x, y, z}, parameters like name or param2 are ignored
-- Returns valid matches as {x, y, z, name, param2} for nodes and {x, y, z, obj} for objects
function nodes_find(vm, nodes, names, objects)
	local nodes_new = {}
	for _, p in ipairs(nodes) do
		local node = vm:get_node_at(p)
		for _, n in ipairs(names) do
			if node.name == n or minetest.get_item_group(node.name, string.sub(n, 7)) > 0 then
				table.insert(nodes_new, {x = p.x, y = p.y, z = p.z, name = node.name, param2 = node.param2})
				break
			end
		end
		if objects then
			for obj in minetest.objects_in_area(vector.subtract(p, 0.5), vector.add(p, 0.5)) do
				local obj_pos = vector.round(obj:get_pos())
				table.insert(nodes_new, {x = obj_pos.x, y = obj_pos.y, z = obj_pos.z, obj = obj})
			end
		end
	end
	return nodes_new
end

-- Generates a shape from the given chain and layer data, returns a list of positions with name and param2 in the format {x, y, z, name, param2}
-- Each node is only listed once to avoid duplicates and improve drawing performance, if a name is specified it replaces the name read from the shape definition
-- The chain contains a list of positions each shape will be centered to, the layer contains lists of shapes with each list drawn at the appropriate link in the chain
function nodes_shape(chain, layer, name)
	local positions = {}
	for i = 1, math.min(#chain, #layer) do
		for _, shape in ipairs(layer[i]) do
			local center_dir = -minetest.facedir_to_dir(chain[i].dir)
			local center_dir_up = {x = -center_dir.y, y = math.max(math.abs(center_dir.x), math.abs(center_dir.z)), z = 0}
			local center_rot = vector.dir_to_rotation(center_dir, center_dir_up)
			local center_ofs = vector.round(vector.rotate(shape.offset, center_rot))
			local center_pos = vector.add(chain[i], center_ofs)
			local sphere = positions_get_sphere(center_pos, shape.radius, shape.roundness)
			for _, p1 in ipairs(sphere) do
				local has = false
				for _, p2 in ipairs(positions) do
					has = vector.equals(p1, p2)
					if has then break end
				end
				if not has then
					local n = name ~= nil and name or shape.nodes[math.random(#shape.nodes)]
					table.insert(positions, {x = p1.x, y = p1.y, z = p1.z, name = n, param2 = 0})
				end
			end
		end
	end
	return positions
end

function snake_timer(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local def = minetest.registered_nodes[node.name]

	local root_radius = def.layers[1][1][1].radius
	local root_roundness = def.layers[1][1][1].roundness
	local chain = minetest.deserialize(meta:get_string("chain"))
	local path = minetest.deserialize(meta:get_string("path"))

	-- Get the largest possible bounding box of the structure based on its chain and biggest shape radius, create the voxel manipulator object
	local bbox_radius = 0
	local bbox_min = vector.copy(pos)
	local bbox_max = vector.copy(pos)
	for _, layer in ipairs(def.layers) do
		for _, shapes in ipairs(layer) do
			for _, shape in ipairs(shapes) do
				if shape.radius > bbox_radius then bbox_radius = shape.radius end
			end
		end
	end
	for _, p in ipairs(chain) do
		if p.x - bbox_radius - 1 < bbox_min.x then bbox_min.x = p.x - bbox_radius - 1 end
		if p.y - bbox_radius - 1 < bbox_min.y then bbox_min.y = p.y - bbox_radius - 1 end
		if p.z - bbox_radius - 1 < bbox_min.z then bbox_min.z = p.z - bbox_radius - 1 end
		if p.x + bbox_radius + 1 > bbox_max.x then bbox_max.x = p.x + bbox_radius + 1 end
		if p.y + bbox_radius + 1 > bbox_max.y then bbox_max.y = p.y + bbox_radius + 1 end
		if p.z + bbox_radius + 1 > bbox_max.z then bbox_max.z = p.z + bbox_radius + 1 end
	end
	local vm = minetest.get_voxel_manip(bbox_min, bbox_max)

	-- Look for targets within the area defined by sight, pathfind from the first positions surrounding the root and goal nodes that produce a valid path
	if #path == 0 or (#path / def.goal_sight) * def.goal_chance >= math.random() then
		path = {}
		local targets = minetest.find_nodes_in_area(vector.subtract(pos, def.goal_sight), vector.add(pos, def.goal_sight), def.nodes_goal, false)
		if #targets > 0 then
			local sphere_start = positions_get_sphere(pos, root_radius + 1, root_roundness)
			for _, target in ipairs(targets) do
				local dist = vector.distance(pos, target)
				if dist >= root_radius * 2 and dist <= def.goal_sight then
					local sphere_end = positions_get_sphere(target, 1, 0)
					for _, pos_end in ipairs(sphere_end) do
						if minetest.get_node(pos_end).name == "air" then
							for _, pos_start in ipairs(sphere_start) do
								if minetest.get_node(pos_start).name == "air" and vector.distance(pos, pos_start) > root_radius then
									path = minetest.find_path(pos_start, pos_end, def.goal_climb, def.goal_climb, def.goal_climb, nil) or {}
								end
								if #path > 0 then break end
							end
						end
						if #path > 0 then break end
					end
				end
				if #path > 0 then break end
			end
		end
	end

	-- Move the root node one unit per turn toward the first path position, remove the position when close enough to proceed to the next one or clear the path if close to the final goal
	-- Root position and chain links contain the vector position with the facedir direction in the format {x, y, z, dir}
	local pos_root = {x = pos.x, y = pos.y, z = pos.z, dir = node.param2}
	if #path > 0 then
		local goal_pos_first = vector.add(path[1], {x = 0, y = def.move_offset, z = 0})
		local goal_pos_last = vector.add(path[#path], {x = 0, y = def.move_offset, z = 0})
		local goal_dir = vector.round(vector.direction(pos, goal_pos_first))
		local goal_pos = vector.add(pos, goal_dir)
		pos_root = {x = goal_pos.x, y = goal_pos.y, z = goal_pos.z, dir = minetest.dir_to_facedir(-goal_dir, true)}
		if vector.distance(pos_root, goal_pos_last) <= root_radius then
			path = {}
		elseif vector.distance(pos_root, goal_pos_first) <= root_radius then
			table.remove(path, 1)
		end
	end

	-- Preform node changes if the root node has moved or spawned, clear nodes from the old chain and draw new ones to the new chain
	-- The system expects the first layer to be the largest and the last to be the smallest, they're used to generate the shells from which nodes are cleared or movable items detected
	-- Node content and vector positions are mixed to make search and replace operations efficient, each node is represented as {x, y, z, name, param2}
	if #chain <= 1 or not vector.equals(pos, pos_root) then
		-- Store the outer shell of the old shape, update the chain to add the new root position and remove links larger than its maximum length
		local shape_clear = nodes_shape(chain, def.layers[1], "air")
		table.insert(chain, 1, pos_root)
		while #chain > #def.layers[1] do
			table.remove(chain, #chain)
		end

		-- Item movement: Store nodes and objects inside the shell that may need to be moved, nodes are stored as {x, y, z, name, param2} and objects as {x, y, z, obj}
		local nodes_move = {}
		local nodes = nodes_find(vm, shape_clear, def.nodes_moves, true)
		for _, p in ipairs(nodes) do
			local m = minetest.get_meta(p)
			p.meta = m:to_table()
			m:from_table(nil)
			table.insert(nodes_move, p)
		end

		-- Clear nodes from the old chain and redraw the shape, layers are drawn in order so that each carves through the shape of the previous layer
		for _, p in ipairs(shape_clear) do
			vm:set_node_at(p, {name = p.name, param2 = p.param2})
		end
		for _, layer in pairs(def.layers) do
			local shape = nodes_shape(chain, layer, nil)
			for _, p in ipairs(shape) do
				vm:set_node_at(p, {name = p.name, param2 = p.param2})
			end
		end

		-- Item movement: Restore movable nodes and unstick objects, if the old position is covered find the closest free position in the chain and move there
		if #nodes_move > 0 then
			local shape_move = nodes_shape(chain, def.layers[#def.layers], "air")
			for _, n1 in ipairs(nodes_move) do
				local n_pos = n1
				local n_current = vm:get_node_at(n_pos)
				local n_blocked = n_current.name ~= "air"
				if n_blocked then
					local closest = vector.distance(bbox_min, bbox_max)
					local nodes_free = nodes_find(vm, shape_move, {"air"}, false)
					for _, n2 in ipairs(nodes_free) do
						local dist = vector.distance(n1, n2)
						if dist < closest then
							closest = dist
							n_pos = n2
						end
						if closest <= 1 then break end
					end
				end

				if n1.name ~= nil then
					vm:set_node_at(n_pos, {name = n1.name, param2 = n1.param2})
					minetest.get_meta(n_pos):from_table(n1.meta)
				elseif n1.obj ~= nil and n_blocked then
					n1.obj:set_pos(n_pos)
				end
			end
		end

		-- Create the new root node and commit changes to the map, update root metadata to store the chain and path
		vm:set_node_at(pos_root, {name = node.name, param2 = pos_root.dir})
		vm:write_to_map()
		local new_meta = minetest.get_meta(pos_root)
		new_meta:set_string("chain", minetest.serialize(chain))
		new_meta:set_string("path", minetest.serialize(path))
	end

	-- Schedule the timer to run again, if LOD is used the time is doubled based on the distance to the closest player
	local lod = 1
	for obj in minetest.objects_inside_radius(pos_root, def.lod_distance) do
		if obj:is_player() then
			local dist = math.min(math.max(vector.distance(pos_root, obj:get_pos()) / def.lod_distance, 0.5), 1)
			if dist < lod then lod = dist end
			if lod <= 0.5 then break end
		end
	end
	local timer = def.time_min + math.random() * (def.time_max - def.time_min)
	local timer_lod = (-0.5 + lod) * 2 * def.lod_time
	minetest.get_node_timer(pos_root):start(timer + timer_lod)
end

function snake_construct(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local pos_root = {x = pos.x, y = pos.y, z = pos.z, dir = node.param2}
	meta:set_string("chain", minetest.serialize({pos_root}))
	meta:set_string("path", minetest.serialize({}))
	minetest.get_node_timer(pos):start(0)
end

function snake_destruct(pos)
	minetest.get_node_timer(pos):stop()
end

-- Node definitions

-- Layers and helper function for adding links recursively
local layer_body = {}
local layer_flesh = {}
local layer_air = {}
function layer_add(layer, segments, shapes)
	for i = 1, segments do
		table.insert(layer, shapes)
	end
end

local shape_body_head_nose = {offset = {x = 0, y = -1, z = 5}, radius = 2, roundness = 0.25, nodes = {"snake:snake_body"}}
local shape_body_head = {offset = {x = 0, y = 0, z = 0}, radius = 5, roundness = 0.25, nodes = {"snake:snake_body"}}
local shape_body_segment = {offset = {x = 0, y = -1, z = 0}, radius = 4, roundness = 0.25, nodes = {"snake:snake_body"}}
local shape_body_tail = {offset = {x = 0, y = -2, z = 0}, radius = 3, roundness = 0.25, nodes = {"snake:snake_body"}}
local shape_flesh_head = {offset = {x = 0, y = 0, z = 0}, radius = 4, roundness = 0.25, nodes = {"snake:snake_flesh"}}
local shape_flesh_segment = {offset = {x = 0, y = -1, z = 0}, radius = 3, roundness = 0.25, nodes = {"snake:snake_flesh"}}
local shape_flesh_tail = {offset = {x = 0, y = -2, z = 0}, radius = 2, roundness = 0.25, nodes = {"snake:snake_flesh"}}
local shape_air_head = {offset = {x = 0, y = 0, z = 0}, radius = 3, roundness = 0.125, nodes = {"air"}}
local shape_air_segment = {offset = {x = 0, y = -1, z = 0}, radius = 2, roundness = 0.125, nodes = {"air"}}
local shape_air_tail = {offset = {x = 0, y = -2, z = 0}, radius = 1, roundness = 0.125, nodes = {"air"}}

layer_add(layer_body, 1, {shape_body_head, shape_body_head_nose})
layer_add(layer_body, 10, {shape_body_segment})
layer_add(layer_body, 5, {shape_body_tail})
layer_add(layer_flesh, 1, {shape_flesh_head})
layer_add(layer_flesh, 10, {shape_flesh_segment})
layer_add(layer_flesh, 5, {shape_flesh_tail})
layer_add(layer_air, 1, {shape_air_head})
layer_add(layer_air, 10, {shape_air_segment})
layer_add(layer_air, 5, {shape_air_tail})

minetest.register_node("snake:snake_heart", {
	description = "Snake heart",
	tiles = {
		"default_furnace_top.png", "default_furnace_bottom.png",
		"default_furnace_side.png", "default_furnace_side.png",
		"default_furnace_side.png", "default_furnace_front.png"
	},
	paramtype2 = "facedir",
	drawtype = "normal",
	light_source = 14,
	waving = 0,
	groups = {snake = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_stone_defaults(),

	layers = {layer_body, layer_flesh, layer_air},
	time_min = 1,
	time_max = 1,
	move_offset = 4,
	lod_time = 5,
	lod_distance = 64,
	goal_chance = 0,
	goal_sight = 64,
	goal_climb = 16,
	nodes_moves = {"group:choppy", "group:snappy", "group:attached_node"},
	nodes_goal = {"default:meselamp"},

	on_timer = snake_timer,
	on_construct = snake_construct,
	on_destruct = snake_destruct,
	on_blast = snake_destruct,
})

minetest.register_node("snake:snake_flesh", {
	description = "Snake flesh",
	tiles = {"default_silver_sand.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	light_source = 0,
	waving = 0,
	groups = {snake = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
})

minetest.register_node("snake:snake_body", {
	description = "Snake body",
	tiles = {"default_silver_sandstone_brick.png"},
	paramtype2 = "facedir",
	drawtype = "normal",
	light_source = 0,
	waving = 0,
	groups = {snake = 1, not_in_creative_inventory = 1, oddly_breakable_by_hand = 1},
	sounds = default.node_sound_dirt_defaults(),
})

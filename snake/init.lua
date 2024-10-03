-- Snake mod by MirceaKitsune
snake = {}

-- Generates and returns the list of sphere positions for the given radius and hardness centered around the given position
-- Each sphere shape is generated once and cached to avoid recalculating it per call
snake.position_cache_sphere = {}
snake.position_get_sphere = function(pos, radius, hardness)
	if radius == 0 then return pos end

	local i = minetest.serialize({radius, hardness})
	if snake.position_cache_sphere[i] == nil then
		snake.position_cache_sphere[i] = {}
		for x = -radius, radius do
			for y = -radius, radius do
				for z = -radius, radius do
					local pos = {x = x, y = y, z = z}
					if hardness >= 1 or vector.distance(pos, vector.zero()) <= radius * (1 + hardness) then
						table.insert(snake.position_cache_sphere[i], pos)
					end
				end
			end
		end
	end

	local positions = {}
	for _, p in pairs(snake.position_cache_sphere[i]) do
		table.insert(positions, vector.add(p, pos))
	end
	return positions
end

-- Returns the position of a facedir rotated offset added to pos
function snake.position_rotated(pos, ofs, dir)
	local dir_up = {x = -dir.y, y = math.max(math.abs(dir.x), math.abs(dir.z)), z = 0}
	local rot = vector.dir_to_rotation(dir, dir_up)
	local offset = vector.round(vector.rotate(ofs, rot))
	return vector.add(pos, offset)
end

-- Returns a random entry from a list of nodes
function snake.node_random(nodes)
	return nodes[math.random(#nodes)]
end

-- Checks whether a node name either has the same name or is part of the same group as a list of nodes
function snake.node_in(name, names)
	for _, n in ipairs(names) do
		if name == n or minetest.get_item_group(name, string.sub(n, 7)) > 0 then return true end
	end
	return false
end

-- If a list of names is provided each position is checked for nodes with that name or in that group, if the objects flag is set each position is searched for entities
-- Search positions only need to contain a position in the format {x, y, z}, parameters like name or param2 are ignored
-- Returns valid matches as {x, y, z, name, param2} for nodes and {x, y, z, obj} for objects
function snake.node_find(vm, nodes, names, objects)
	local nodes_new = {}
	for _, p in ipairs(nodes) do
		local node = vm:get_node_at(p)
		if snake.node_in(node.name, names) then
			table.insert(nodes_new, {x = p.x, y = p.y, z = p.z, name = node.name, param2 = node.param2})
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
-- Each node is only listed once to avoid duplicates and improve drawing performance, if the name list isn't empty it replaces the name read from the shape definition
-- The chain contains a list of positions each shape will be centered to, the layer contains lists of shapes with each list drawn at the appropriate link in the chain
function snake.node_shape(chain, layer, name)
	local positions = {}
	for i = 1, math.min(#chain, #layer) do
		for _, shape in ipairs(layer[i]) do
			local center = snake.position_rotated(chain[i], shape.position, -minetest.facedir_to_dir(chain[i].dir))
			local sphere = snake.position_get_sphere(center, shape.radius, shape.roundness)
			for _, p1 in ipairs(sphere) do
				local has = false
				for _, p2 in ipairs(positions) do
					has = vector.equals(p1, p2)
					if has then break end
				end
				if not has then
					local n = #name > 0 and snake.node_random(name) or snake.node_random(shape.nodes)
					table.insert(positions, {x = p1.x, y = p1.y, z = p1.z, name = n, param2 = 0})
				end
			end
		end
	end
	return positions
end

function snake.timer(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local def = minetest.registered_nodes[node.name]
	local pos_root = {x = pos.x, y = pos.y, z = pos.z, dir = node.param2}

	-- Only preform updates if a player is closer than the LOD range or LOD is disabled
	local update = def.lod == 0
	if not update then
		for obj in minetest.objects_inside_radius(pos_root, def.lod) do
			if obj:is_player() then
				update = true
				break
			end
		end
	end

	if update then
		local root_radius = def.layers[1][1][1].radius
		local root_roundness = def.layers[1][1][1].roundness
		local chain = minetest.deserialize(meta:get_string("chain"))
		local path = minetest.deserialize(meta:get_string("path"))

		-- Get the largest possible bounding box of the structure based on its chain and largest shape, create the voxel manipulator object for this area
		local bbox_dist = 0
		local bbox_min = vector.copy(pos)
		local bbox_max = vector.copy(pos)
		for _, layer in ipairs(def.layers) do
			for _, shapes in ipairs(layer) do
				for _, shape in ipairs(shapes) do
					local max_radius = shape.radius + math.max(math.abs(shape.position.x), math.abs(shape.position.y), math.abs(shape.position.z))
					if max_radius > bbox_dist then bbox_dist = max_radius end
				end
			end
		end
		for _, p in ipairs(chain) do
			if p.x - bbox_dist - 1 < bbox_min.x then bbox_min.x = p.x - bbox_dist - 1 end
			if p.y - bbox_dist - 1 < bbox_min.y then bbox_min.y = p.y - bbox_dist - 1 end
			if p.z - bbox_dist - 1 < bbox_min.z then bbox_min.z = p.z - bbox_dist - 1 end
			if p.x + bbox_dist + 1 > bbox_max.x then bbox_max.x = p.x + bbox_dist + 1 end
			if p.y + bbox_dist + 1 > bbox_max.y then bbox_max.y = p.y + bbox_dist + 1 end
			if p.z + bbox_dist + 1 > bbox_max.z then bbox_max.z = p.z + bbox_dist + 1 end
		end
		local vm = minetest.get_voxel_manip(bbox_min, bbox_max)

		-- Look for targets within the area defined by sight, travel from the eye position to the best goal determined by the pathfinder
		if #path == 0 or def.goal_chance >= math.random() then
			local pos_start = snake.position_rotated(pos_root, def.goal_position, -minetest.facedir_to_dir(pos_root.dir))
			local targets = minetest.find_nodes_in_area(vector.subtract(pos_root, def.goal_sight), vector.add(pos_root, def.goal_sight), def.nodes_goal, false)
			for _, target in ipairs(targets) do
				local pos_end = vector.add(target, {x = 0, y = 1, z = 0})
				local dist = vector.distance(pos_start, pos_end)
				if dist >= root_radius * 2 and dist <= def.goal_sight then
					local path_new = minetest.find_path(pos_start, pos_end, def.goal_climb, def.goal_climb, def.goal_climb, nil)
					if path_new ~= nil then path = path_new end
				end
			end
		end

		-- Move the root node one unit per turn toward the first path position, remove the position when close enough to proceed to the next one or clear the path if close to the final goal
		-- Root position and chain links contain the vector position with the facedir direction in the format {x, y, z, dir}
		if #path > 0 then
			local goal_pos_first = vector.add(path[1], {x = 0, y = def.height, z = 0})
			local goal_pos_last = vector.add(path[#path], {x = 0, y = def.height, z = 0})
			local goal_dir = vector.round(vector.direction(pos, goal_pos_first))
			local goal_pos = vector.add(pos, goal_dir)
			local dist_reached = math.round(root_radius / 2)
			pos_root = {x = goal_pos.x, y = goal_pos.y, z = goal_pos.z, dir = minetest.dir_to_facedir(-goal_dir, true)}
			if vector.distance(pos_root, goal_pos_last) <= dist_reached then
				path = {}
			elseif vector.distance(pos_root, goal_pos_first) <= dist_reached then
				table.remove(path, 1)
			end
		end

		-- Preform node changes if the root node has moved or spawned, clear nodes from the old chain and draw new ones to the new chain
		-- The system expects the first layer to be the largest and the last to be the smallest, they're used to generate the shells from which nodes are cleared or movable items detected
		-- Node content and vector positions are mixed to make search and replace operations efficient, each node is represented as {x, y, z, name, param2}
		if #chain <= 1 or not vector.equals(pos, pos_root) then
			-- Store the outer shell of the old shape, update the chain to add the new root position and remove links larger than its maximum length
			local shape_clear = snake.node_shape(chain, def.layers[1], def.nodes_clear)
			table.insert(chain, 1, pos_root)
			while #chain > #def.layers[1] do
				table.remove(chain, #chain)
			end

			-- Item movement: Store nodes and objects inside the shell that may need to be moved, nodes are stored as {x, y, z, name, param2} and objects as {x, y, z, obj}
			local nodes_move = {}
			local nodes = snake.node_find(vm, shape_clear, def.nodes_moves, true)
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
				local shape = snake.node_shape(chain, layer, {})
				for _, p in ipairs(shape) do
					vm:set_node_at(p, {name = p.name, param2 = p.param2})
				end
			end

			-- Item movement: Restore movable nodes and unstick objects, if the old position is covered find the closest free position in the chain and move there
			if #nodes_move > 0 then
				local shape_move = snake.node_shape(chain, def.layers[#def.layers], {})
				for _, n1 in ipairs(nodes_move) do
					local n_pos = n1
					local n_current = vm:get_node_at(n_pos)
					local n_free = snake.node_in(n_current.name, def.nodes_clear)
					if not n_free then
						local closest = vector.distance(bbox_min, bbox_max)
						local nodes_free = snake.node_find(vm, shape_move, def.nodes_clear, false)
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
					elseif n1.obj ~= nil and not n_free then
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
	end

	-- Schedule the timer to run again
	local timer = def.time_min + math.random() * (def.time_max - def.time_min)
	minetest.get_node_timer(pos_root):start(timer)
end

function snake.construct(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local pos_root = {x = pos.x, y = pos.y, z = pos.z, dir = node.param2}
	meta:set_string("chain", minetest.serialize({pos_root}))
	meta:set_string("path", minetest.serialize({}))
	minetest.get_node_timer(pos):start(0)
end

function snake.destruct(pos)
	minetest.get_node_timer(pos):stop()
end

function snake.register_node(name, data)
	data.on_timer = snake.timer
	data.on_construct = snake.construct
	data.on_destruct = snake.destruct
	data.on_blast = snake.destruct
	minetest.register_node(name, data)
end

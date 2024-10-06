-- Snake mod by MirceaKitsune
snake = {}
snake.shapes = {}
snake.dir4 = {{x = -1, y = 0, z = 0}, {x = 1, y = 0, z = 0}, {x = 0, y = 0, z = -1}, {x = 0, y = 0, z = 1}}
snake.dir6 = {{x = -1, y = 0, z = 0}, {x = 1, y = 0, z = 0}, {x = 0, y = -1, z = 0}, {x = 0, y = 1, z = 0}, {x = 0, y = 0, z = -1}, {x = 0, y = 0, z = 1}}

-- Returns the position of a facedir rotated offset added to pos
function snake.rotated(pos, ofs, dir)
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

-- Caches the nodes of every shape for all possible facedir rotations, the code uses this to avoid rotating nodes in realtime
-- Storage order: Name, layer, shape, facedir
function snake.shapes_set(name)
	snake.shapes[name] = {}
	for l, layer in ipairs(minetest.registered_nodes[name].layers) do
		snake.shapes[name][l] = {}
		for i, nodes in ipairs(layer) do
			snake.shapes[name][l][i] = {}
			for _, dir in ipairs(snake.dir6) do
				local nodes_hash = {}
				local facedir = minetest.dir_to_facedir(-vector.new(dir))
				snake.shapes[name][l][i][facedir] = {}
				for _, node in ipairs(nodes) do
					local hash = minetest.hash_node_position(node)
					if nodes_hash[hash] == nil then
						nodes_hash[hash] = node.name
						local pos = snake.rotated(vector.zero(), node, dir)
						table.insert(snake.shapes[name][l][i][facedir], {x = pos.x, y = pos.y, z = pos.z, name = node.name, param2 = facedir})
					end
				end
			end
		end
	end
end

-- Returns a shape for the given chain and layer data as a list of positions with name and param2 in the format {x, y, z, name, param2}
-- The chain contains a list of positions each shape will be centered to, if the name list isn't empty it replaces the name read from the shape definition
function snake.shapes_get(name, l, chain, names)
	local nodes_hash = {}
	local nodes = {}
	local layer = snake.shapes[name][l]
	for i = 1, math.min(#chain, #layer) do
		local facedir = chain[i].param2
		local dir = -minetest.facedir_to_dir(facedir)
		local shape = layer[i][facedir]
		for _, n in ipairs(shape) do
			local n_pos = vector.add(chain[i], n)
			local n_name = #names > 0 and snake.node_random(names) or snake.node_random(n.name)
			local hash = minetest.hash_node_position(n_pos)
			if nodes_hash[hash] == nil then
				nodes_hash[hash] = n_name
				table.insert(nodes, {x = n_pos.x, y = n_pos.y, z = n_pos.z, name = n_name, param2 = facedir})
			end
		end
	end
	return nodes
end

function snake.timer(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local def = minetest.registered_nodes[node.name]
	local pos_root = {x = pos.x, y = pos.y, z = pos.z, param2 = node.param2}

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
		local chain = minetest.deserialize(meta:get_string("chain"))
		local path = minetest.deserialize(meta:get_string("path"))

		-- Get the largest possible bounding box of the structure based on its chain and largest shape, create the voxel manipulator object for this area
		local bbox_dist = 0
		local bbox_min = vector.copy(pos)
		local bbox_max = vector.copy(pos)
		for _, layer in ipairs(def.layers) do
			for _, nodes in ipairs(layer) do
				for _, node in ipairs(nodes) do
					local max_radius = math.max(math.abs(node.x), math.abs(node.y), math.abs(node.z))
					if max_radius > bbox_dist then bbox_dist = max_radius end
				end
			end
		end
		for _, p in ipairs(#chain > 0 and chain or {pos_root}) do
			if p.x - bbox_dist - 1 < bbox_min.x then bbox_min.x = p.x - bbox_dist - 1 end
			if p.y - bbox_dist - 1 < bbox_min.y then bbox_min.y = p.y - bbox_dist - 1 end
			if p.z - bbox_dist - 1 < bbox_min.z then bbox_min.z = p.z - bbox_dist - 1 end
			if p.x + bbox_dist + 1 > bbox_max.x then bbox_max.x = p.x + bbox_dist + 1 end
			if p.y + bbox_dist + 1 > bbox_max.y then bbox_max.y = p.y + bbox_dist + 1 end
			if p.z + bbox_dist + 1 > bbox_max.z then bbox_max.z = p.z + bbox_dist + 1 end
		end
		local vm = minetest.get_voxel_manip(bbox_min, bbox_max)

		-- Look for targets within the area defined by sight, travel from the eye position to the best goal determined by the pathfinder
		if def.chance_path >= math.random() then
			local targets = minetest.find_nodes_in_area(vector.subtract(pos_root, def.sight_max), vector.add(pos_root, def.sight_max), def.nodes_goal, false)
			for obj in minetest.objects_inside_radius(pos_root, def.sight_max) do
				if obj:is_player() and snake.node_in(obj:get_wielded_item():get_name(), def.nodes_goal_wield) then
					table.insert(targets, vector.round(obj:get_pos()))
				end
			end

			local pos_start = snake.rotated(pos_root, def.position_eye, -minetest.facedir_to_dir(pos_root.param2))
			for _, target in ipairs(targets) do
				local pos_end = vector.add(target, {x = 0, y = 1, z = 0})
				local dist = vector.distance(pos_start, pos_end)
				if dist >= def.sight_min and dist <= def.sight_max then
					local path_new = {}
					local path_get = minetest.find_path(pos_start, pos_end, def.goal_climb, def.goal_climb, def.goal_climb, nil) or {}
					for _, p in pairs(path_get) do
						local p_new = {x = p.x, y = p.y + def.height, z = p.z}
						if snake.node_in(minetest.get_node(p_new).name, def.nodes_clear) then
							table.insert(path_new, p_new)
						else break end
					end
					if #path_new > 0 then
						path = path_new
						break
					end
				end
			end
		end

		-- Move the root node one unit per turn toward the first path position, remove the position when close enough to proceed to the next one or clear the path if close to the final goal
		-- The chains of other snakes are checked and radiuses compared, movement is paused if this snake could cut through another snake
		-- Root position and chain links contain the vector position with the facedir direction in the format {x, y, z, param2}
		if def.chance_move >= math.random() and #path > 0 then
			local goal_dir = vector.round(vector.direction(pos, path[1]))
			local goal_pos = vector.add(pos, goal_dir)
			local roots = minetest.find_nodes_in_area(vector.subtract(pos_root, def.sight_max), vector.add(pos_root, def.sight_max), {"group:snake_root"}, false)
			for _, p1 in ipairs(roots) do
				if not vector.equals(pos_root, p1) then
					local n = minetest.get_node(p1)
					local m = minetest.get_meta(p1):to_table()
					local c = minetest.deserialize(m.fields.chain)
					for _, p2 in ipairs(c) do
						local r = def.radius + minetest.registered_nodes[n.name].radius
						if vector.distance(goal_pos, p2) <= r then goal_pos = nil end
						if goal_pos == nil then break end
					end
				end
				if goal_pos == nil then break end
			end

			if goal_pos == nil then
				pos_root.param2 = minetest.dir_to_facedir(-goal_dir, true)
			else
				pos_root = {x = goal_pos.x, y = goal_pos.y, z = goal_pos.z, param2 = minetest.dir_to_facedir(-goal_dir, true)}
				if math.floor(vector.distance(pos_root, path[#path])) <= def.radius then
					path = {}
				elseif math.floor(vector.distance(pos_root, path[1])) <= def.radius then
					table.remove(path, 1)
				end
			end
		end

		-- Decide if to turn the head in a random direction, avoid looking back into self by discarding offsets that match the second chain position
		if def.chance_look >= math.random() then
			local dirs = {}
			for _, dir in ipairs(snake.dir4) do
				if #chain <= 1 or not vector.equals(vector.subtract(pos, dir), chain[2]) then
					table.insert(dirs, dir)
				end
			end
			pos_root.param2 = minetest.dir_to_facedir(dirs[math.random(#dirs)])
		end

		-- Preform node changes if the root node has moved or spawned, clear nodes from the old chain and draw new ones to the new chain
		-- The system expects the first layer to be the largest, used to generate the shells from which nodes are cleared or movable items detected
		-- Node content and vector positions are mixed to make search and replace operations efficient, each node is represented as {x, y, z, name, param2}
		if #chain == 0 or node.param2 ~= pos_root.param2 or not vector.equals(pos, pos_root) then
			-- Store the outer shells of the old and new shapes using clear nodes then update the chain
			-- If the head moved add its new position and remove links larger than the maximum length, if it only rotated update its entry instead
			local shape_old = snake.shapes_get(def.name, 1, chain, def.nodes_clear)
			if vector.equals(pos, pos_root) then
				chain[1] = pos_root
			else
				table.insert(chain, 1, pos_root)
				while #chain > #def.layers[1] do
					table.remove(chain, #chain)
				end
			end
			local shape_new = snake.shapes_get(def.name, 1, chain, def.nodes_clear)

			-- Item movement: Store nodes and objects inside the shell that may need to be moved, nodes are stored as {x, y, z, name, param2} and objects as {x, y, z, obj}
			local nodes_move = {}
			local nodes = snake.node_find(vm, shape_old, def.nodes_moves, true)
			for _, p in ipairs(nodes) do
				if p.name ~= nil then
					local m = minetest.get_meta(p)
					p.meta = m:to_table()
					m:from_table(nil)
				end
				table.insert(nodes_move, p)
			end

			-- Clear nodes from the old chain and redraw the shape, layers are drawn in order so that each carves through the shape of the previous layer
			for _, p in ipairs(shape_old) do
				vm:set_node_at(p, {name = p.name, param2 = p.param2})
			end

			for l = 1, #def.layers do
				local shape = snake.shapes_get(def.name, l, chain, {})
				for _, p in ipairs(shape) do
					vm:set_node_at(p, {name = p.name, param2 = p.param2})
				end
			end

			-- Item movement: Restore movable nodes and unstick objects, if the old position is covered find the closest free position in the chain and move there
			if #nodes_move > 0 then
				for _, n1 in ipairs(nodes_move) do
					local n_pos = n1
					local n_current = vm:get_node_at(n_pos)
					local n_free = snake.node_in(n_current.name, def.nodes_clear)
					if not n_free then
						local closest = vector.distance(bbox_min, bbox_max)
						local nodes_free = snake.node_find(vm, shape_new, def.nodes_clear, false)
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

			-- Create the new root node and commit changes to the map, call the destruct and construct functions on old and new nodes, set root metadata to the updated chain and path
			for _, p in ipairs(shape_old) do
				local d = minetest.registered_nodes[minetest.get_node(p).name]
				if d.on_destruct ~= nil then d.on_destruct(p) end
			end
			vm:set_node_at(pos_root, {name = node.name, param2 = pos_root.param2})
			vm:write_to_map()
			for _, p in ipairs(shape_new) do
				local d = minetest.registered_nodes[minetest.get_node(p).name]
				if d.on_construct ~= nil then d.on_construct(p) end
			end
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
	meta:set_string("chain", minetest.serialize({}))
	meta:set_string("path", minetest.serialize({}))
	minetest.get_node_timer(pos):start(0)
end

function snake.destruct(pos)
	minetest.get_node_timer(pos):stop()
end

function snake.register_node(name, data)
	data.groups.snake = 1
	minetest.register_node(name, data)
end

function snake.register_root(name, data)
	data.groups.snake = 1
	data.groups.snake_root = 1
	data.on_timer = snake.timer
	data.on_construct = snake.construct
	data.on_destruct = snake.destruct
	data.on_blast = snake.destruct
	minetest.register_node(name, data)
	snake.shapes_set(name)
end

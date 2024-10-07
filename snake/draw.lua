-- Snake mod by MirceaKitsune
snake.draw = {}

-- Returns a single node wrapped in a list
function snake.draw.single(name, pos)
	return {{x = pos.x, y = pos.y, z = pos.z, name = name}}
end

-- Returns the list of nodes filling the given area
function snake.draw.fill(name, pos_min, pos_max)
	local nodes = {}
	for x = pos_min.x, pos_max.x do
		for y = pos_min.y, pos_max.y do
			for z = pos_min.z, pos_max.z do
				table.insert(nodes, {x = x, y = y, z = z, name = name})
			end
		end
	end
	return nodes
end

-- Returns the list of nodes in an area for the given radius and hardness
function snake.draw.round(name, pos, radius, hardness)
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

-- Returns the combined result of the provided node lists with duplicate entries discarded
function snake.draw.add(nodes_list)
	local nodes_hash = {}
	local nodes = {}
	for _, nodes_list in pairs(nodes_list) do
		for _, n in pairs(nodes_list) do
			local hash = minetest.hash_node_position(n)
			if nodes_hash[hash] == nil then
				nodes_hash[hash] = n.name
				table.insert(nodes, {x = n.x, y = n.y, z = n.z, name = n.name})
			end
		end
	end
	return nodes
end

-- Returns the first list of nodes without entries in the second list
function snake.draw.subtract(nodes_add, nodes_sub)
	local nodes = {}
	for _, n1 in pairs(nodes_add) do
		table.insert(nodes, {x = n1.x, y = n1.y, z = n1.z, name = n1.name})
		for _, n2 in pairs(nodes_sub) do
			if vector.equals(n1, n2) then
				table.remove(nodes, #nodes)
				break
			end
		end
	end
	return nodes
end

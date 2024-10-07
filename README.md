# Node snake for Minetest

A customizable node based snake that moves around. Spawn one, place an objective node nearby, and watch it travel the world! WIP and highly experimental.

## API

The mod works by having a single root node representing the head / heart / engine move around the world and store its previous positions to form a chain, filling each link in this chain with shapes to draw a cordon across its path. Changes are written to the map each time the structure moves or updates in place after all calculations have been preformed in the voxel manipulator. Since many node changes and collision calculations are preformed internally, it's best to use small shapes with short chains and decrease the update rate the larger the structure is. The following properties must be defined in the root node:

  - `layers`: A list containing a node list for every segment at this position in the chain. Layers are drawn in an orderly fashion to create the final shape, with later layers carving new nodes through the nodes drawn by former layers: The first layer is expected to be the largest and longest encompassing the exterior of the structure, the system uses its data to clear nodes during updates and detect movable items. Each node is represented by a position and name, use helper functions to generate the final list. Example of an unpacked layers definition: `{{{{x = 0, y = -1, z = 2, name = "snake:snake_body"}, next_node}, next_link}, next_layer}`.
  - `radius`: Must represent the radius of the largest shape in any layer as closely as possible. Used in pathfinding and collision detection, too low values may cause snakes to cut through one another.
  - `time_min`: Minimum number of seconds before an update or movement is preformed.
  - `time_max`: Maximum number of seconds before an update or movement is preformed, the timer is constant if equal to the minimum value or random if this is set higher.
  - `lod`: Distance in which a viewer must be present for updates to be preformed, if no players are closer than this distance pathfinding and movement are suspended. Lower values improve server performance by reducing node updates when no one is close enough to see them, but going too low will cause the snake to sleep when seen from closer up.
  - `chance_path`: Chance of picking a new goal. Small values may reduce performance and cause the snake to get confused by intersecting self, large values may delay obstacle detection and updating the path. A value of 0.1 is recommended.
  - `chance_move`: If a valid path exists, chance of moving per turn. Lower values make snakes take breaks more often, higher values move more frequently.
  - `chance_look`: Random chance for the head turning in a random direction. Useful as a detail as well as reducing the risk of the snake getting stuck if the head is buried in one direction and can't pathfind.
  - `position_eye`: The virtual eye from which the snake starts pathfinding to nearby goals. Adjust based on the head scale so this position is in front of the eyes and close to the ground such as `{x = 0, y = -2, z = 4}`, experiment with this value if pathfinding doesn't work or the snake tends to climb into the air.
  - `height`: Height offset when moving toward the goal. Set to the raduis of the largest shape for perfect alignment with the ground, lower to make the structure cut through terrain slightly, higher values will make the snake float above the ground.
  - `sight_min`: Noses must be this far from the root node to be considered valid targets, should be at least as large as the snake's length for safe results.
  - `sight_max`: Range in which the root node will search for targets and pick a node or object to navigate to.
  - `goal_climb`: Number of nodes the snake can climb up or down as well as go around obstacles to reach the goal. This shouldn't be higher than the total length of the snake or that may cause it to climb through the air.
  - `nodes_clear`: The list of nodes representing empty spaces. Pathfinding will only accept routes that traverse nodes listed here, also used to fill the area left behind by the snake and detect movable items inside the structure. This will usually be `{"air"}` but if the snake is meant to move through water using `{"default:water_source"}` is more appropriate. Only use a non-solid node representing the medium this snake moves through, walkable nodes may cause pathfinding to fail!
  - `nodes_moves`: Nodes located inside the snake will be moved with it as it navigates, only works if the item is in a node listed under `nodes_clear`. Nodes and groups not set here will instead be erased when the structure passes over them. Don't add nodes belonging to the snake in this group which may produce an infinite trail of nodes!
  - `nodes_goal`: The snake looks for nodes of this type when picking a target to walk toward.
  - `nodes_goal_wield`: The snake will follow players wielding any of the items listed here, if `""` is included the snake also follows players that aren't holding anything.

Egg nodes are made available to the player and can be placed on the ground to hatch a snake after a defined period of time. The root node will only be activated when placed by an egg, placing it manually will result in a standard node. The following properties are set for egg nodes:

  - `nodes_root`: The type of root node that will be spawned when this egg hatches. The root node is created at the `height` offset defined in its settings.
  - `time_min`: Minimum number of seconds before the egg may hatch.
  - `time_max`: Maximum number of seconds before the egg may hatch.

All snake nodes must be registered using the functions described below, which automatically assign core variables and handle shape caching. The following groups are assigned and may be used to detect snake nodes: `"snake"` for all nodes making up the body of a snake, `"snake_root"` to describe the root node, `"snake_egg"` to describe egg nodes.

  - `snake.register_node`: For registering body nodes that are created and destroyed as the snake moves.
  - `snake.register_root`: For registering the root node, automatically assigns the following builtin functions:
    - `on_timer`: Must be set to `snake.root_timer`.
    - `on_construct`: Must be set to `snake.root_construct`.
    - `on_destruct`: Must be set to `snake.root_destruct`.
    - `on_blast`: Must be set to `snake.root_destruct`.
  - `snake.register_egg`: For registering egg nodes, automatically assigns the following builtin functions:
    - `on_timer`: Must be set to `snake.egg_timer`.
    - `on_construct`: Must be set to `snake.egg_construct`.
    - `on_destruct`: Must be set to `snake.egg_destruct`.
    - `on_blast`: Must be set to `snake.egg_destruct`.

The API offers a shape library to facilitate drawing multiple nodes as part of the `snake.draw` object, containing optional helper functions mods can use to automate certain operations and node shapes. Draw functions include:

  - `snake.draw.single(name, pos)`: Returns a single node wrapped in a list.
  - `snake.draw.fill(name, pos_min, pos_max)`: Returns the list of nodes filling the given area.
  - `snake.draw.round(name, pos, radius, hardness)`: Returns the list of nodes in an area for the given radius and hardness. If hardness is 0 this will be a fully round sphere, if 1 a cube is returned instead.
  - `snake.draw.add(nodes_list)`: Returns the combined result of the provided node lists with duplicate entries discarded. Nodes set first have priority, later nodes at the same position will be ignored.
  - `snake.draw.subtract(nodes_add, nodes_sub)`: Returns the first list of nodes without entries in the second list. The names of nodes in the subtraction list are ignored as only positions are relevant.

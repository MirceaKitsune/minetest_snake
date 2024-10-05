# Node snake for Minetest

A customizable node based snake that moves around. Spawn one, place an objective node nearby, and watch it travel the world! WIP and highly experimental.

## API

The mod works by having a single root node representing the head / heart / engine move around the world and remember its previous positions to form a chain, filling each link in this chain with spheres to draw a cordon across its path. Changes are written to the map each time the structure moves or updates in place after all calculations have been preformed in the voxel manipulator object. Since a lot of node changes and collision calculations are preformed internally, it's best to use small radiuses with short chains and decrease the update rate the larger the structure is. The following properties must be configured on the root node:

  - `layers`: A list containing sphere shape instructions for each segment at this position in the chain.
    - `shapes`: Each entry must be a list containing sphere shape instructions for each segment in the chain. Each entry must be an object containing the following parameters:
      - `position`: Offset of this shape relative to its chain link. For example `{x = 0, y = -1, z = 2}` will position the sphere one node lower and two nodes in front of where the root node is facing. Use this to create more complex forms such as nose / eyes / etc. Shapes will be roated around this point, the center acts as the equivalent of an armature joint, account for bending before moving too far.
      - `radius`: The radius that determines how large the sphere for this segment is. This value represents the number of nodes from the center, for example 4 means a 9 node wide sphere (-4 to 4 including 0).
      - `roundness`: Blends between the shape of a sphere and that of a square to make the sphere more bulky. 0 makes spheres as round as possible, 0.25 and below is recommended for rounded shapes, 0.5 and above will draw squares with rounded edges, 1 produces squares instead of spheres.
      - `nodes`: A list of nodes to pick from when filling this shape. At least one node must be listed for example `{"snake:snake_body"}`. If more than one node exists one is randomly picked each time a sphere is drawn, you can include the same node multiple times to increase its probability.
  - `time_min`: Minimum number of seconds before an update or movement is preformed.
  - `time_max`: Maximum number of seconds before an update or movement is preformed, the timer is constant if equal to the minimum value or random if this is set higher.
  - `lod`: Distance in which a viewer must be present for updates to be preformed, if no players are closer than this distance pathfinding and movement are suspended. Lower values improve server performance by reducing node updates when no one is close enough to see them, but going too low will cause the snake to sleep when seen from closer up.
  - `look`: Random chance for the head turning in a random direction. Useful as a detail as well as reducing the risk of the snake getting stuck if the head is buried in one direction and can't pathfind.
  - `height`: Height offset when moving toward the goal. Set to the raduis of the largest shape for perfect alignment with the ground, lower to make the structure cut through terrain slightly, higher values will make the snake float above the ground.
  - `goal_position`: The virtual eye from which the snake starts pathfinding to nearby goals. Adjust based on the head scale so this position is in front of the eyes and close to the ground such as `{x = 0, y = -2, z = 4}`, experiment with this value if pathfinding doesn't work or the snake tends to climb into the air.
  - `goal_chance`: Chance of picking a new goal per execution. Small values may reduce performance and cause the snake to get confused by intersecting self, large values may delay obstacle detection and updating the path. A value of 0.1 is recommended.
  - `goal_sight_min`: Noses must be this far from the root node to be considered valid targets, should be at least as large as the snake's length for safe results.
  - `goal_sight_max`: Range in which the root node will search for targets and pick a node or object to navigate to.
  - `goal_climb`: Number of nodes the snake can climb up or down as well as go around obstacles to reach the goal. This shouldn't be higher than the total length of the snake or that may cause it to climb through the air.
  - `nodes_clear`: The list of nodes representing empty spaces. Pathfinding will only accept routes that traverse nodes listed here, also used to fill the area left behind by the snake and detect movable items inside the structure. This will usually be `{"air"}` but if the snake is meant to move through water using `{"default:water_source"}` is more appropriate. Only use a non-solid node representing the medium this snake moves through, walkable nodes may cause pathfinding to fail!
  - `nodes_moves`: Nodes located inside the snake will be moved with it as it navigates, only works if the item is in a node listed under `nodes_clear`. Nodes and groups not set here will instead be erased when the structure passes over them. Don't add nodes belonging to the snake in this group which may produce an infinite trail of nodes!
  - `nodes_goal`: The snake looks for nodes of this type when picking a target to walk toward.
  - `nodes_goal_wield`: The snake will follow players wielding any of the items listed here, if "" is included the snake also follows players that aren't holding anything.

The root node should be registered using `snake.register_node`, which still expects the above entries but automatically assigns the following base functions:

  - `on_timer`: Must be set to `snake_timer`.
  - `on_construct`: Must be set to `snake_construct`.
  - `on_destruct`: Must be set to `snake_destruct`.
  - `on_blast`: Must be set to `snake_destruct`.

Layer ordering and usage: Layers are drawn in order to create the final shape, with later layers carving new nodes through the nodes drawn by former layers. The first layer is thus expected to be the largest and longest encompassing the exterior of the structure, the last should be the smallest and will usually contain air: The system uses their data to clear the structure during updates and detect movable items. The first link in each layer is the root node and the last will be the tail: The first shape of the first link in the first layer should represent the head size and is used in pathfinding.

Example of a packed layer definition, use variables or helper functions to simplify and repeat shapes. The first level the layer list, second level is the list of shapes that layer be draw per chain link, the third level is the list containing the objects for each shape to be drawn at that link by the layer.

`layers = {{{{offset = {x = 0, y = 0, z = 0}, radius = 4, roundness = 0.25, nodes = {"snake:snake_body"}}, next_shape}, next_link}, next_layer}`

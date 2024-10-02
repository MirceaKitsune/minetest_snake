# Node snake for Minetest

A customizable node based snake that moves around. Spawn one, place an objective node nearby, and watch it travel the world! WIP and highly experimental.

## API

The mod works by having a single node representing the heart / engine move around the world and remember its previous positions to form a chain, filling each link in this chain with spheres to draw a cordon across its path. Changes are written to the map each time the structure moves or updates in place after all calculations have been preformed in the voxel manipulator object. Since a lot of node changes and collision calculations are preformed internally, it's best to use small radiuses with short chains and decrease the update rate the larger the structure is. The following properties must be configured on the heart node:

  - `layers`: A list containing sphere shape instructions for each segment at this position in the chain.
    - `shapes`: Each entry must be a list containing sphere shape instructions for each segment in the chain. Each entry must be an object containing the following parameters:
      - `offset`: Offsets this sphere. The global XYZ components of the sphere center is bumped by this amount, for example `{x = 0, y = -1, z = 0}` will position the sphere one node lower. The snake will change shape when climbing or falling, values that are too high may cause the shape to appear crushed or disconnected from the rest of the body.
      - `radius`: The radius that determines how large the sphere for this segment is. This value represents the number of nodes from the center, for example 4 means a 9 node wide sphere (-4 to 4 including 0).
      - `roundness`: Blends between the shape of a sphere and that of a square to make the sphere more bulky. 0 makes spheres as round as possible, 0.25 and below is recommended for rounded shapes, 0.5 and above will draw squares with rounded edges, 1 produces squares instead of spheres.
      - `nodes`: A list of nodes to pick from when filling this shape. At least one node must be listed for example `{"snake:snake_body"}`. If more than one node exists one is randomly picked each time a sphere is drawn, you can include the same node multiple times to increase its probability.
  - `time_min`: Minimum number of seconds before an update or movement is preformed.
  - `time_max`: Maximum number of seconds before an update or movement is preformed, the timer is constant if equal to the minimum value or random if this is set higher.
  - `lod_distance`: Maximum distance in nodes up to which LOD takes effect, minimum distance is half of this setting. If there are no players closer than this range, the maximum LOD level is used... if at least one player is closer than halfway the range, LOD is disabled. Higher values improve server performance by reducing node updates when no one is close enough to see them, but going too high will cause the snake to move slower and not update for a while even after a player gets close.
  - `lod_time`: Time added to timer on top of `time_min` and `time_max` when the highest LOD level is active. The timer won't be affected when a player is close enough to disable LOD, or if this is set to zero to disable timer LOD for this node.
  - `move_offset`: Height offset when moving toward the goal. Set to the raduis of the largest shape for perfect alignment with the ground, lower to make the structure cut through terrain slightly, higher values will make the snake float above the ground.
  - `goal_chance`: Chance of picking a new goal and path before reaching the existing one, higher the further the head is from the goal. Small values may reduce performance and cause the snake to get confused by self intersection, large values may delay obstacle detection and updating the path. 0.1 is recommended.
  - `goal_sight`: Range in which the head will search for targets and pick a node to navigate to.
  - `goal_climb`: Number of nodes the snake can climb up or down as well as go around obstacles to reach the goal. This shouldn't be higher than the total length of the snake or that may cause it to climb through the air.
  - `nodes_moves`: Nodes located inside the snake will be moved with it as it navigates. Nodes and groups not set here will instead be erased when the structure passes over them. Don't add nodes belonging to the snake in this group which may produce an infinite trail of nodes.
  - `nodes_goal`: The snake looks for nodes of this type when picking a target to walk toward.

  - `on_timer`: Must be set to `snake_timer`.
  - `on_construct`: Must be set to `snake_construct`.
  - `on_destruct`: Must be set to `snake_destruct`.
  - `on_blast`: Must be set to `snake_destruct`.

Layer ordering and usage: Layers are drawn in order to create the final shape, with later layers carving new nodes through the nodes drawn by former layers. The first layer is thus expected to be the largest and longest encompassing the exterior of the structure, the last should be the smallest and will usually contain air: The system uses their data to clear the structure during updates and detect movable items. The first link in each layer is the head and the last will be the tail: The first shape of the first link in the first layer should represent the head size and is used in pathfinding.

Example of a packed layer definition, use variables or helper functions to simplify and repeat shapes. The first level the layer list, second level is the list of shapes that layer be draw per chain link, the third level is the list containing the objects for each shape to be drawn at that link by the layer.

`layers = {{{{offset = {x = 0, y = 0, z = 0}, radius = 4, roundness = 0.25, nodes = {"snake:snake_body"}}, next_shape}, next_link}, next_layer}`

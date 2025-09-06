# GridMovement.gd - Updated with dynamic obstacle detection
extends Node
class_name GridMovement

signal movement_finished
signal arrived_at_waypoint(position: Vector2i)

var villager: Villager
var pathfinder: GridPathfinder
var current_path: Array[Vector2i] = []
var current_waypoint_index: int = 0
var target_world_position: Vector3
var movement_speed: float = 3.0
var is_moving: bool = false

# Continuous movement variables
var current_position: Vector3
var movement_direction: Vector3
var distance_to_current_target: float = 0.0

# Dynamic obstacle detection
var final_destination: Vector3
var last_obstacle_check_time: float = 0.0
var obstacle_check_interval: float = 0.5  # Check every 0.5 seconds

func _init(villager_ref: Villager):
	villager = villager_ref

func _ready():
	pathfinder = GridPathfinder.new(Vector2i(49, 49))
	update_pathfinder_obstacles()
	
	# Connect to building movement signals for dynamic obstacle detection
	if BuildModeManager:
		BuildModeManager.building_selection_changed.connect(_on_building_moved_check)

func _on_building_moved_check(building):
	# This gets called when buildings are selected, but we need building movement
	# Let's connect to the building movement signal instead
	pass

func update_pathfinder_obstacles():
	pathfinder.set_blocked_tiles(BuildModeManager.occupied_tiles.duplicate())

func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(round(world_pos.x)), int(round(world_pos.z)))

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x, 0.1, grid_pos.y)

func move_to_position(target_world_pos: Vector3) -> bool:
	print("=== GRID MOVEMENT ===")
	print("Moving from ", villager.global_position, " to ", target_world_pos)
	
	final_destination = target_world_pos  # Store for recalculation
	return recalculate_path()

func recalculate_path() -> bool:
	update_pathfinder_obstacles()
	
	var start_grid = world_to_grid(villager.global_position)
	var target_grid = world_to_grid(final_destination)
	
	print("Grid coordinates: ", start_grid, " -> ", target_grid)
	
	current_path = pathfinder.find_path(start_grid, target_grid)
	
	if current_path.is_empty():
		print("No path found!")
		return false
	
	print("Path found with ", current_path.size(), " waypoints: ", current_path)
	
	current_waypoint_index = 0
	is_moving = true
	current_position = villager.global_position
	current_position.y = 0.1
	set_next_target()
	return true

func set_next_target():
	if current_waypoint_index >= current_path.size():
		finish_movement()
		return
	
	var waypoint_grid = current_path[current_waypoint_index]
	target_world_position = grid_to_world(waypoint_grid)
	
	# Calculate direction and distance
	movement_direction = (target_world_position - current_position).normalized()
	distance_to_current_target = current_position.distance_to(target_world_position)
	
	print("Next target: ", waypoint_grid, " (distance: ", distance_to_current_target, ")")

func check_path_still_valid() -> bool:
	# Check if any of the remaining waypoints in our path are now blocked
	for i in range(current_waypoint_index, current_path.size()):
		var waypoint = current_path[i]
		if not pathfinder.is_tile_walkable(waypoint):
			print("Path blocked at waypoint ", i, ": ", waypoint)
			return false
	return true

func _physics_process(delta):
	if not is_moving:
		return
	
	# Periodically check for new obstacles in our path
	last_obstacle_check_time += delta
	if last_obstacle_check_time >= obstacle_check_interval:
		last_obstacle_check_time = 0.0
		
		update_pathfinder_obstacles()  # Get latest obstacle info
		
		if not check_path_still_valid():
			print("Path blocked! Recalculating...")
			if not recalculate_path():
				print("No alternative path found - stopping movement")
				finish_movement()
				return
	
	# Move toward current target
	var movement_this_frame = movement_direction * movement_speed * delta
	var distance_this_frame = movement_this_frame.length()
	
	if distance_this_frame >= distance_to_current_target:
		# We'll reach or overshoot the target this frame
		current_position = target_world_position
		current_waypoint_index += 1
		arrived_at_waypoint.emit(current_path[current_waypoint_index - 1])
		
		# Immediately set next target without stopping
		if current_waypoint_index < current_path.size():
			set_next_target()
		else:
			finish_movement()
			return
	else:
		# Normal movement toward target
		current_position += movement_this_frame
		distance_to_current_target -= distance_this_frame
	
	# Update villager position
	villager.global_position = current_position
	
	# Rotate villager to face movement direction
	if movement_direction.length() > 0.1:
		var flat_direction = Vector3(movement_direction.x, 0, movement_direction.z).normalized()
		if flat_direction.length() > 0.1:
			var target_rotation = atan2(flat_direction.x, flat_direction.z)
			# Smooth rotation
			villager.rotation.y = lerp_angle(villager.rotation.y, target_rotation, 8.0 * delta)

func finish_movement():
	is_moving = false
	current_path.clear()
	current_waypoint_index = 0
	last_obstacle_check_time = 0.0
	villager.velocity = Vector3.ZERO
	villager.global_position.y = 0.1
	movement_finished.emit()
	print("Grid movement finished!")

func stop_movement():
	is_moving = false
	current_path.clear()
	last_obstacle_check_time = 0.0
	villager.velocity = Vector3.ZERO

func redirect_to_position(new_target_world_pos: Vector3) -> bool:
	if not is_moving:
		return move_to_position(new_target_world_pos)
	
	print("Redirecting movement to new target: ", new_target_world_pos)
	final_destination = new_target_world_pos
	return recalculate_path()

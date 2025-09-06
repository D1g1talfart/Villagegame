extends Node

signal build_mode_toggled(is_active: bool)
signal building_selection_changed(building: BuildableBuilding)
signal house_built(house_building: BuildableBuilding)

enum BuildMode { MOVE_EXISTING, PLACE_NEW }

var is_build_mode_active: bool = false
var selected_building: BuildableBuilding = null
var current_build_mode: BuildMode = BuildMode.MOVE_EXISTING
var building_to_place: BuildingData = null
var placement_preview: Node3D = null
var buffer_zones_visible: bool = false
var grid_size: Vector2i = Vector2i(49, 49)
var occupied_tiles: Dictionary = {}
var kitchen_tiles: Array[Vector2i] = []
var all_buildings: Array[BuildableBuilding] = []

func _ready():
	var center = grid_size / 2
	for x in range(center.x - 1, center.x + 2):
		for y in range(center.y - 1, center.y + 2):
			kitchen_tiles.append(Vector2i(x, y))
			occupied_tiles[Vector2i(x, y)] = null

func _input(event):
	if not is_build_mode_active:
		return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_build_mode == BuildMode.MOVE_EXISTING:
				handle_build_mode_click()
			else: # PLACE_NEW
				handle_placement_click()

func handle_build_mode_click():
	# Existing move building logic
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2  # Buildings are on layer 2
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider is BuildableBuilding:
			print("Clicked on building: ", collider.building_name)
			select_building(collider)
			return
	
	if selected_building:
		attempt_move_selected_building()
	else:
		print("Clicked on empty space, no building selected")

func handle_placement_click():
	print("Attempting to place new building: ", building_to_place.display_name)
	
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Cast ray to ground
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground layer
	var result = space_state.intersect_ray(query)
	
	if result:
		var world_pos = result.position
		var grid_pos = Vector2i(int(round(world_pos.x)), int(round(world_pos.z)))
		
		print("Attempting to place at grid position: ", grid_pos)
		
		if can_place_new_building_at(building_to_place, grid_pos):
			place_new_building(building_to_place, grid_pos)
		else:
			print("Cannot place building at ", grid_pos)

func can_place_new_building_at(building_data: BuildingData, grid_pos: Vector2i) -> bool:
	# Existing bounds checks
	if grid_pos.x < 0 or grid_pos.y < 0:
		return false
	if grid_pos.x + building_data.size.x > grid_size.x:
		return false
	if grid_pos.y + building_data.size.y > grid_size.y:
		return false
	
	# Check for direct tile occupation conflicts
	for x in range(building_data.size.x):
		for y in range(building_data.size.y):
			var check_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
			
			if check_pos in kitchen_tiles:
				print("Cannot place - conflicts with kitchen at ", check_pos)
				return false
			
			if check_pos in occupied_tiles:
				print("Cannot place - tile occupied at ", check_pos)
				return false
	
	# NEW: Check buffer zone violations
	if would_violate_buffer_zones(building_data, grid_pos):
		print("Cannot place - violates 1-tile buffer zone rule")
		return false
	
	return true

func place_new_building(building_data: BuildingData, grid_pos: Vector2i):
	print("Placing new building: ", building_data.display_name, " at ", grid_pos)
	
	# Load and instantiate the building scene (existing code)
	if building_data.scene_path.is_empty():
		print("ERROR: No scene path for ", building_data.display_name)
		return
	
	var building_scene = load(building_data.scene_path)
	if not building_scene:
		print("ERROR: Could not load scene: ", building_data.scene_path)
		return
	
	var new_building = building_scene.instantiate()
	if not new_building:
		print("ERROR: Could not instantiate building")
		return
	
	# Add to the village scene
	var village = get_tree().current_scene
	village.add_child(new_building)
	
	# Position the building
	new_building.position = Vector3(grid_pos.x, 0.1, grid_pos.y)
	
	# Register the building
	register_building(new_building, grid_pos)
	
	# Confirm placement with BuildingShop
	BuildingShop.confirm_building_placed(building_data)
	
	# Special handling for houses - emit signal to spawn villager
	if building_data.building_type == BuildingData.BuildingType.HOUSE:
		house_built.emit(new_building)
		print("House built - signaling for new villager spawn")
	
	print("Successfully placed ", building_data.display_name, " at ", grid_pos)
	
	# NEW: Update buffer zones since we just placed a new building
	if is_build_mode_active:
		show_buffer_zones()  # Refresh to include the new building's buffer
	
	# Exit placement mode AND build mode completely
	exit_placement_mode_and_build_mode()

func enter_placement_mode(building_data: BuildingData):
	print("Entering placement mode for: ", building_data.display_name)
	building_to_place = building_data
	current_build_mode = BuildMode.PLACE_NEW
	
	if not is_build_mode_active:
		toggle_build_mode()
	
	deselect_building()  # Clear any selected building
	
	# TODO: Could add placement preview here
	print("Click on the map to place your ", building_data.display_name)

func exit_placement_mode():
	print("Exiting placement mode")
	current_build_mode = BuildMode.MOVE_EXISTING
	building_to_place = null
	
	# Remove placement preview if we had one
	if placement_preview:
		placement_preview.queue_free()
		placement_preview = null
		
func exit_placement_mode_and_build_mode():
	print("Exiting placement mode and build mode completely")
	exit_placement_mode()
	
	# Exit build mode completely
	if is_build_mode_active:
		toggle_build_mode()

func toggle_build_mode():
	is_build_mode_active = !is_build_mode_active
	build_mode_toggled.emit(is_build_mode_active)
	
	if not is_build_mode_active:
		deselect_building()
		exit_placement_mode()
		clear_buffer_zone_indicators()
		buffer_zones_visible = false  # Track visibility
		print("Build mode deactivated")
	else:
		show_buffer_zones()
		buffer_zones_visible = true  # Track visibility
		print("Build mode activated")

# Rest of existing functions stay the same...
func select_building(building: BuildableBuilding):
	if selected_building != building:
		selected_building = building
		building_selection_changed.emit(building)
		print("Selected building: ", building.building_name)

func deselect_building():
	selected_building = null
	building_selection_changed.emit(null)
	print("Deselected building")

func register_building(building: BuildableBuilding, grid_pos: Vector2i):
	all_buildings.append(building)
	building.grid_position = grid_pos
	for tile in building.get_occupied_tiles():
		occupied_tiles[tile] = building

func can_place_building_at(building: BuildableBuilding, grid_pos: Vector2i) -> bool:
	# Existing bounds checks
	if grid_pos.x < 0 or grid_pos.y < 0:
		return false
	if grid_pos.x + building.building_size.x > grid_size.x:
		return false
	if grid_pos.y + building.building_size.y > grid_size.y:
		return false
	
	# Check for direct conflicts
	for x in range(building.building_size.x):
		for y in range(building.building_size.y):
			var check_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
			
			if check_pos in kitchen_tiles:
				return false
			
			if check_pos in occupied_tiles and occupied_tiles[check_pos] != building:
				return false
	
	# NEW: Check buffer zones (exclude the building being moved)
	if would_violate_buffer_zones(building, grid_pos, building):
		print("Cannot move - violates 1-tile buffer zone rule")
		return false
	
	return true

func move_building_to_position(building: BuildableBuilding, new_grid_pos: Vector2i):
	# First, clear the building from its old position
	clear_building_from_grid(building)
	
	# CRITICAL: Update the building's position in the grid BEFORE emitting signals
	building.grid_position = new_grid_pos  # Set the position first
	for tile in building.get_occupied_tiles():  # This now uses the NEW position
		occupied_tiles[tile] = building
	
	# Update all pathfinders with new obstacle data BEFORE villagers start pathfinding
	update_all_active_pathfinders()
	
	# NOW move the building visually and emit the signal (this triggers villager redirect)
	building.position = Vector3(new_grid_pos.x, building.position.y, new_grid_pos.y)
	building.building_moved.emit(building, new_grid_pos)
	
	if buffer_zones_visible:
		show_buffer_zones()
	
	print("Moved ", building.building_name, " to ", new_grid_pos)

func update_all_active_pathfinders():
	# Get all villagers and update their pathfinders
	var villagers = get_tree().get_nodes_in_group("villagers")
	for villager in villagers:
		if villager.has_method("get") and villager.grid_movement:
			villager.grid_movement.update_pathfinder_obstacles()
	print("Updated pathfinders for ", villagers.size(), " villagers")

func clear_building_from_grid(building: BuildableBuilding):
	for tile in building.get_occupied_tiles():
		if tile in occupied_tiles and occupied_tiles[tile] == building:
			occupied_tiles.erase(tile)

func attempt_move_selected_building():
	if not selected_building:
		return
	
	print("Attempting to move selected building")
	
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground layer
	var result = space_state.intersect_ray(query)
	
	if result:
		var world_pos = result.position
		var grid_pos = Vector2i(int(round(world_pos.x)), int(round(world_pos.z)))
		
		print("Target position: ", grid_pos)
		
		if can_place_building_at(selected_building, grid_pos):
			move_building_to_position(selected_building, grid_pos)
			deselect_building()
		else:
			print("Cannot place building at ", grid_pos)
			

# Add this function to get all tiles within buffer range of a position
func get_tiles_in_buffer_range(center_pos: Vector2i, range: int = 1) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(-range, range + 1):
		for y in range(-range, range + 1):
			var tile = Vector2i(center_pos.x + x, center_pos.y + y)
			if tile.x >= 0 and tile.y >= 0 and tile.x < grid_size.x and tile.y < grid_size.y:
				tiles.append(tile)
	return tiles

# Check if a position is within buffer zone of any existing building
func is_within_buffer_zone_of_buildings(grid_pos: Vector2i, exclude_building: BuildableBuilding = null) -> bool:
	# Check all existing buildings
	for building in all_buildings:
		if building == exclude_building:
			continue  # Skip the building we're trying to move
			
		# Check if grid_pos is within 1 tile of any tile this building occupies
		var building_tiles = building.get_occupied_tiles()
		for building_tile in building_tiles:
			var distance = max(abs(grid_pos.x - building_tile.x), abs(grid_pos.y - building_tile.y))
			if distance <= 1:  # Within 1-tile buffer
				print("Position ", grid_pos, " is within buffer of ", building.building_name, " at ", building_tile)
				return true
	
	# Also check kitchen tiles explicitly (in case kitchen wasn't registered)
	for kitchen_tile in kitchen_tiles:
		var distance = max(abs(grid_pos.x - kitchen_tile.x), abs(grid_pos.y - kitchen_tile.y))
		if distance <= 1:
			print("Position ", grid_pos, " is within buffer of Kitchen at ", kitchen_tile)
			return true
	
	return false

# Check if any tiles in an area would violate buffer zones
func would_violate_buffer_zones(building_data_or_building, grid_pos: Vector2i, exclude_building: BuildableBuilding = null) -> bool:
	var size: Vector2i
	
	# Handle both BuildingData and BuildableBuilding
	if building_data_or_building is BuildingData:
		size = building_data_or_building.size
	else:
		size = building_data_or_building.building_size
	
	# Check each tile the building would occupy
	for x in range(size.x):
		for y in range(size.y):
			var check_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
			if is_within_buffer_zone_of_buildings(check_pos, exclude_building):
				return true
	
	return false
	
func show_buffer_zones():
	clear_buffer_zone_indicators()
	
	var all_buffer_tiles = {}  # Use dictionary to avoid duplicates
	
	# Get buffer zones from regular buildings
	for building in all_buildings:
		var building_tiles = building.get_occupied_tiles()
		for tile in building_tiles:
			var buffer_tiles = get_tiles_in_buffer_range(tile, 1)
			for buffer_tile in buffer_tiles:
				if buffer_tile not in occupied_tiles and buffer_tile not in kitchen_tiles:
					all_buffer_tiles[buffer_tile] = true  # Use as set
	
	# Add buffer zones around kitchen tiles
	for kitchen_tile in kitchen_tiles:
		var buffer_tiles = get_tiles_in_buffer_range(kitchen_tile, 1)
		for buffer_tile in buffer_tiles:
			if buffer_tile not in occupied_tiles and buffer_tile not in kitchen_tiles:
				all_buffer_tiles[buffer_tile] = true
	
	# Create indicators for unique buffer tiles
	for buffer_tile in all_buffer_tiles.keys():
		create_buffer_zone_indicator(buffer_tile)

func create_buffer_zone_indicator(grid_pos: Vector2i):
	# Create a small red indicator to show buffer zone
	var indicator = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.8, 0.05, 0.8)
	indicator.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0, 0.3)  # Semi-transparent red
	material.flags_transparent = true
	indicator.material_override = material
	
	indicator.position = Vector3(grid_pos.x, 0.05, grid_pos.y)
	indicator.name = "BufferZoneIndicator_" + str(grid_pos.x) + "_" + str(grid_pos.y)
	get_tree().current_scene.add_child(indicator)

func clear_buffer_zone_indicators():
	var scene = get_tree().current_scene
	var indicators_to_remove = []
	
	# Collect all indicators first
	for child in scene.get_children():
		if child.name.begins_with("BufferZoneIndicator_"):
			indicators_to_remove.append(child)
	
	# Remove them IMMEDIATELY, not at end of frame
	for indicator in indicators_to_remove:
		indicator.free()  # Use free() instead of queue_free() for immediate removal
	
	print("Immediately cleared ", indicators_to_remove.size(), " buffer zone indicators")

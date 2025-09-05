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
	if grid_pos.x < 0 or grid_pos.y < 0:
		return false
	if grid_pos.x + building_data.size.x > grid_size.x:
		return false
	if grid_pos.y + building_data.size.y > grid_size.y:
		return false
	
	for x in range(building_data.size.x):
		for y in range(building_data.size.y):
			var check_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
			
			if check_pos in kitchen_tiles:
				return false
			
			if check_pos in occupied_tiles:
				return false
	
	return true

func place_new_building(building_data: BuildingData, grid_pos: Vector2i):
	print("Placing new building: ", building_data.display_name, " at ", grid_pos)
	
	# Load and instantiate the building scene
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
		print("Build mode deactivated")
	else:
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
	if grid_pos.x < 0 or grid_pos.y < 0:
		return false
	if grid_pos.x + building.building_size.x > grid_size.x:
		return false
	if grid_pos.y + building.building_size.y > grid_size.y:
		return false
	
	for x in range(building.building_size.x):
		for y in range(building.building_size.y):
			var check_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
			
			if check_pos in kitchen_tiles:
				return false
			
			if check_pos in occupied_tiles and occupied_tiles[check_pos] != building:
				return false
	
	return true

func move_building_to_position(building: BuildableBuilding, new_grid_pos: Vector2i):
	clear_building_from_grid(building)
	building.move_to_grid_position(new_grid_pos)
	for tile in building.get_occupied_tiles():
		occupied_tiles[tile] = building

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
			

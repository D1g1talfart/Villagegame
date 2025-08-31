# Updated BuildModeManager.gd
extends Node

signal build_mode_toggled(is_active: bool)
signal building_selection_changed(building: BuildableBuilding)

var is_build_mode_active: bool = false
var selected_building: BuildableBuilding = null
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
			handle_build_mode_click()

func handle_build_mode_click():
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Cast ray to find what we clicked
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2  # Buildings are on layer 2
	var result = space_state.intersect_ray(query)
	
	if result:
		# We hit something - check if it's a building
		var collider = result.collider
		if collider is BuildableBuilding:
			print("Clicked on building: ", collider.building_name)
			select_building(collider)
			return
	
	# If we get here, we clicked on empty space
	if selected_building:
		attempt_move_selected_building()
	else:
		print("Clicked on empty space, no building selected")

func attempt_move_selected_building():
	if not selected_building:
		return
	
	print("Attempting to move selected building")
	
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
		
		print("Target position: ", grid_pos)
		
		if can_place_building_at(selected_building, grid_pos):
			move_building_to_position(selected_building, grid_pos)
			deselect_building()  # Deselect after successful move
		else:
			print("Cannot place building at ", grid_pos)

func toggle_build_mode():
	is_build_mode_active = !is_build_mode_active
	build_mode_toggled.emit(is_build_mode_active)
	
	if not is_build_mode_active:
		deselect_building()

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

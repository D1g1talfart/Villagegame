# Complete corrected Village.gd
extends Node3D

@onready var camera_controller = $CameraController
@onready var mobile_ui = $MobileUI

var farm_scene = preload("res://Farm.tscn")
var house_scene = preload("res://House.tscn")
var villager_scene = preload("res://Villager.tscn")

func _ready():
	setup_lighting()
	generate_map()
	setup_ground_collision()
	setup_navigation_region()
	setup_mobile_controls()
	setup_build_mode()
	spawn_initial_buildings()
	setup_jobs_and_villagers()

func setup_lighting():
	var sun_light = DirectionalLight3D.new()
	sun_light.name = "Sun"
	sun_light.position = Vector3(0, 20, 0)
	sun_light.rotation_degrees = Vector3(-45, -30, 0)
	sun_light.light_energy = 1.0
	add_child(sun_light)
	
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_energy = 0.3
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = environment
	add_child(world_env)

func generate_map():
	var map_size = 49
	var tile_size = 1.0
	
	# Create grass tiles
	for x in range(map_size):
		for z in range(map_size):
			var grass_tile = create_grass_tile()
			grass_tile.position = Vector3(x * tile_size, 0, z * tile_size)
			add_child(grass_tile)
	
	# Create kitchen in center (3x3)
	create_kitchen_building()

func create_kitchen_building():
	var center = 49 / 2
	
	# Create the kitchen tiles visually
	for x in range(center - 1, center + 2):
		for z in range(center - 1, center + 2):
			var kitchen_tile = create_kitchen_tile()
			kitchen_tile.position = Vector3(x, 0.1, z)
			add_child(kitchen_tile)
	
	# Create the Kitchen building node
	var kitchen = Kitchen.new()
	kitchen.name = "Kitchen"
	kitchen.position = Vector3(center, 0.1, center)
	
	# ADD COLLISION TO KITCHEN
	var collision_body = StaticBody3D.new()
	collision_body.name = "KitchenCollision"
	collision_body.collision_layer = 2  # Same layer as other buildings
	collision_body.collision_mask = 0
	
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3, 1, 3)  # 3x3 kitchen size, 1 unit tall
	collision_shape.shape = shape
	collision_shape.position = Vector3(0, 0.5, 0)  # Center the collision box
	
	collision_body.add_child(collision_shape)
	kitchen.add_child(collision_body)
	
	add_child(kitchen)
	
	print("Kitchen created with collision at: ", kitchen.position)

func create_grass_tile():
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.9, 0.1, 0.9)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	mesh_instance.material_override = material
	
	return mesh_instance

func create_kitchen_tile():
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.9, 0.2, 0.9)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.3, 0.1)
	mesh_instance.material_override = material
	
	return mesh_instance

func setup_ground_collision():
	var ground_body = StaticBody3D.new()
	ground_body.name = "Ground"
	add_child(ground_body)
	
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(50, 0.1, 50)
	collision_shape.shape = shape
	ground_body.add_child(collision_shape)
	
	ground_body.position = Vector3(24.5, -0.05, 24.5)
	ground_body.collision_layer = 1

func setup_mobile_controls():
	if mobile_ui and camera_controller:
		mobile_ui.zoom_in_pressed.connect(_on_mobile_zoom_in)
		mobile_ui.zoom_out_pressed.connect(_on_mobile_zoom_out)

func _on_mobile_zoom_in():
	camera_controller.camera.size = clamp(camera_controller.camera.size - 2.0, 
										 camera_controller.min_zoom, 
										 camera_controller.max_zoom)

func _on_mobile_zoom_out():
	camera_controller.camera.size = clamp(camera_controller.camera.size + 2.0, 
										 camera_controller.min_zoom, 
										 camera_controller.max_zoom)

func setup_build_mode():
	BuildModeManager.build_mode_toggled.connect(_on_build_mode_toggled)

func _on_build_mode_toggled(is_active: bool):
	print("Build mode: ", "ON" if is_active else "OFF")
	
	if is_active:
		print("Click buildings to select them, then click ground to move them")
	else:
		print("Build mode disabled")

func spawn_initial_buildings():
	# Spawn a farm at position (10, 10)
	var farm = farm_scene.instantiate()
	add_child(farm)
	farm.position = Vector3(10, 0.1, 10)
	BuildModeManager.register_building(farm, Vector2i(10, 10))
	
	# Spawn a house at position (15, 15)
	var house = house_scene.instantiate()
	add_child(house)
	house.position = Vector3(15, 0.1, 15)
	BuildModeManager.register_building(house, Vector2i(15, 15))

func setup_jobs_and_villagers():
	await get_tree().process_frame
	setup_building_jobs()
	spawn_initial_villagers()

func setup_building_jobs():
	# Jobs are now registered automatically when buildings are created
	# This function can be simplified or removed
	print("Building jobs setup complete")
	

func spawn_initial_villagers():
	var house = find_house_building()
	if house:
		spawn_villager("Bob", house)
	else:
		print("Warning: No house found for villager spawn")

func find_kitchen_building():
	for child in get_children():
		if child is Kitchen:  # Look for Kitchen class specifically
			return child
	print("Warning: Kitchen not found")
	return null

func find_house_building():  # Fixed - no return type  
	for child in get_children():
		if child is BuildableBuilding and child.building_name == "House":
			return child
	print("Warning: House not found")
	return null

func spawn_villager(villager_name: String, house):
	var villager = villager_scene.instantiate()
	villager.name = villager_name
	villager.villager_name = villager_name
	villager.home_house = house
	
	add_child(villager)
	villager.global_position = house.global_position + Vector3(1.5, 0, 0)
	
	JobManager.register_villager(villager)
	print("Spawned villager: ", villager_name)

# Add this to Village.gd for testing
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		BuildModeManager.toggle_build_mode()
	
	# TEST: Press 'T' to create a simple UI in code
	if event.is_action_pressed("ui_accept"):
		create_test_ui()
	
	if not BuildModeManager.is_build_mode_active:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				handle_job_assignment_click()

func create_test_ui():
	print("Creating test UI...")
	
	# Create a simple UI entirely in code
	var test_control = Control.new()
	test_control.size = Vector2(1152, 648)
	test_control.position = Vector2.ZERO
	
	var test_panel = Panel.new()
	test_panel.size = Vector2(300, 200)
	test_panel.position = Vector2(200, 200)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color.GREEN
	test_panel.add_theme_stylebox_override("panel", style)
	
	var test_label = Label.new()
	test_label.text = "TEST UI WORKING!"
	test_label.position = Vector2(50, 50)
	
	test_panel.add_child(test_label)
	test_control.add_child(test_panel)
	get_tree().root.add_child(test_control)
	
	print("Test UI created and added to scene")

func handle_job_assignment_click():
	print("=== CLICK DEBUG ===")
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2  # Buildings on layer 2
	var result = space_state.intersect_ray(query)
	
	if result:
		var clicked_object = result.collider
		print("Clicked object: ", clicked_object.name)
		
		# Check if it's a regular BuildableBuilding
		if clicked_object is BuildableBuilding:
			var building = clicked_object as BuildableBuilding
			if building.has_meta("job"):
				var job = building.get_meta("job") as Job
				JobManager.show_job_assignment_ui(job)
				print("Clicked on job site: ", building.building_name)
		
		# Check if it's the kitchen collision body
		elif clicked_object.name == "KitchenCollision":
			var kitchen = clicked_object.get_parent()
			if kitchen.has_method("is_kitchen") and kitchen.has_meta("job"):
				var job = kitchen.get_meta("job") as Job
				JobManager.show_job_assignment_ui(job)
				print("Clicked on kitchen")
		
		else:
			print("Clicked object is not a building: ", clicked_object)

func setup_navigation_region():
	print("Setting up navigation region...")
	
	# Simple approach: Create a flat navigation mesh over the whole ground
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion"
	add_child(nav_region)
	
	# Create navigation mesh
	var nav_mesh = NavigationMesh.new()
	
	# Create a simple box mesh for navigation
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Simple ground plane for navigation (49x49 map)
	vertices.append(Vector3(0, 0, 0))      # Bottom-left
	vertices.append(Vector3(49, 0, 0))     # Bottom-right  
	vertices.append(Vector3(49, 0, 49))    # Top-right
	vertices.append(Vector3(0, 0, 49))     # Top-left
	
	# Two triangles to make a rectangle
	indices.append_array([0, 1, 2])        # First triangle
	indices.append_array([0, 2, 3])        # Second triangle
	
	nav_mesh.vertices = vertices
	nav_mesh.polygons.clear()
	nav_mesh.add_polygon(indices)
	
	nav_region.navigation_mesh = nav_mesh
	
	print("Navigation region created with mesh")

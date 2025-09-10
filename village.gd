extends Node3D

@onready var camera_controller = $CameraController
@onready var mobile_ui = $MobileUI

var farm_scene = preload("res://Farm.tscn")
var house_scene = preload("res://House.tscn")
var villager_scene = preload("res://Villager.tscn")
var kitchen_scene = preload("res://Kitchen.tscn")

var villager_names: Array[String] = [
	"Bob", "Alice", "Charlie", "Diana", "Edward", "Fiona", "George", "Hannah",
	"Isaac", "Julia", "Kevin", "Luna", "Marcus", "Nina", "Oscar", "Petra",
	"Quinn", "Rosa", "Samuel", "Tessa", "Ulrich", "Vera", "Walter", "Xara",
	"York", "Zara", "Alex", "Blake", "Casey", "Drew", "Emery", "Finley"
]
var next_villager_index: int = 0 


func _ready():
	add_to_group("village")
	setup_lighting()
	generate_map()
	setup_ground_collision()
	#setup_navigation_region()
	setup_mobile_controls()
	setup_build_mode()
	spawn_initial_buildings()
	setup_jobs_and_villagers()
	
	# Connect to house building signal
	BuildModeManager.house_built.connect(_on_house_built)


func setup_lighting():
	var sun_light = DirectionalLight3D.new()
	sun_light.name = "Sun"
	sun_light.position = Vector3(0, 20, 0)
	sun_light.rotation_degrees = Vector3(-45, -30, 0)
	sun_light.light_energy = 1.5
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

# village.gd - Replace create_kitchen_building() with this clean version
func create_kitchen_building():
	var center = 49 / 2
	
	# Load and instantiate the Kitchen scene
	var kitchen = kitchen_scene.instantiate()
	kitchen.name = "Kitchen"
	kitchen.position = Vector3(center, 0.1, center)
	
	# Set the grid position immediately
	kitchen.grid_position = Vector2i(center - 1, center - 1)  # Top-left corner of 3x3
	
	add_child(kitchen)
	
	# Register with BuildModeManager
	BuildModeManager.register_building(kitchen, Vector2i(center - 1, center - 1))
	
	print("Kitchen scene created at: ", kitchen.position, " (no overlapping tiles)")


func create_grass_tile():
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1, 0.01, 1)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	
	# Load the grass texture
	var grass_texture = load("res://Textures/Grass.png") as Texture2D
	if grass_texture:
		material.albedo_texture = grass_texture
	else:
		print("WARNING: Could not load grass texture - using green color fallback")
		material.albedo_color = Color.GREEN
	
	# Optional: You can still tint the texture with a color if needed
	# material.albedo_color = Color.WHITE  # White = no tint, shows texture as-is
	
	# Optional: Adjust texture tiling if the texture is too big/small per tile
	material.uv1_scale = Vector3(3, 2, 2)  # Adjust these values to tile the texture
	
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
		mobile_ui.build_mode_toggled.connect(_on_mobile_build_mode_toggled)

func _on_mobile_zoom_in():
	camera_controller.camera.size = clamp(camera_controller.camera.size - 2.0, 
										 camera_controller.min_zoom, 
										 camera_controller.max_zoom)

func _on_mobile_zoom_out():
	camera_controller.camera.size = clamp(camera_controller.camera.size + 2.0, 
										 camera_controller.min_zoom, 
										 camera_controller.max_zoom)
										
func _on_mobile_build_mode_toggled():
	# The mobile UI already calls BuildModeManager.toggle_build_mode()
	# This is just for any additional logic you might want
	print("Build mode toggled via mobile UI")

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
	# CRITICAL: Set grid_position IMMEDIATELY after instantiation, before adding to scene
	farm.grid_position = Vector2i(35, 35)
	add_child(farm)
	farm.position = Vector3(35, 0.1, 35)
	BuildModeManager.register_building(farm, Vector2i(10, 10))
	
	# Spawn a house at position (30, 15) - testing the new location
	var house = house_scene.instantiate()
	# CRITICAL: Set grid_position IMMEDIATELY after instantiation, before adding to scene  
	house.grid_position = Vector2i(30, 30)
	add_child(house)
	house.position = Vector3(30, 0.1, 30)
	BuildModeManager.register_building(house, Vector2i(30, 15))
	
	print("Initial buildings spawned with correct grid positions")
	print("Farm grid_position: ", farm.grid_position)
	print("House grid_position: ", house.grid_position)

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
		# Use the naming system instead of hardcoding "Bob"
		var first_villager_name = get_next_villager_name()  # This will be "Bob"
		spawn_villager(first_villager_name, house)
	else:
		print("Warning: No house found for villager spawn")


func _on_house_built(house_building: BuildableBuilding):
	print("=== NEW HOUSE BUILT ===")
	print("House position: ", house_building.position)
	
	# Generate villager name
	var villager_name = get_next_villager_name()
	
	# Spawn villager at the new house
	spawn_villager(villager_name, house_building)
	
	print("New villager ", villager_name, " spawned for new house!")

func get_next_villager_name() -> String:
	if next_villager_index < villager_names.size():
		var name = villager_names[next_villager_index]
		next_villager_index += 1
		print("Assigned name: ", name, " (index was ", next_villager_index - 1, ")")
		return name
	else:
		# Fallback to numbered names if we run out
		var fallback_name = "Villager " + str(next_villager_index + 1)
		next_villager_index += 1
		return fallback_name

# village.gd - Replace find_kitchen_building() with this fixed version
func find_kitchen_building():
	for child in get_children():
		if child.has_method("is_kitchen") and child.is_kitchen():  # Use the method instead of class check
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
	villager.global_position = house.global_position + Vector3(0, 0, 2)
	
	JobManager.register_villager(villager)
	print("Spawned villager: ", villager_name)
	
	# Make sure the villager connects to house signals after it's ready
	# (This is now handled in the villager's _ready function)

# Add this to Village.gd for testing
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		BuildModeManager.toggle_build_mode()
	
	# TEST: Press 'T' to create a simple UI in code
	if event.is_action_pressed("ui_accept"):
		create_test_ui()
	
	if event.is_action_pressed("ui_up"):
		BuildingShop.set_player_level(BuildingShop.player_level + 1)
	elif event.is_action_pressed("ui_down") and BuildingShop.player_level > 1:
		BuildingShop.set_player_level(BuildingShop.player_level - 1)
	
	# FIXED: Check if any UI is open before handling job assignment clicks
	if not BuildModeManager.is_build_mode_active and not is_any_ui_open():
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				handle_job_assignment_click()

# Add this new function to village.gd
func is_any_ui_open() -> bool:
	# Check if shop UI is open
	if mobile_ui and mobile_ui.building_shop_ui and mobile_ui.building_shop_ui.visible:
		return true
	
	# Check if job assignment UI is open
	var job_ui = get_tree().root.get_node_or_null("SimpleJobUI")
	if job_ui:
		return true
	
	return false

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

# village.gd - Replace setup_navigation_region() with this improved version
func setup_navigation_region():
	print("Setting up navigation region...")
	
	# Wait for all buildings to be ready with their obstacles
	await get_tree().process_frame
	await get_tree().process_frame
	
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion"
	add_child(nav_region)
	
	# Create navigation mesh with better settings
	var nav_mesh = NavigationMesh.new()
	
	# Configure navigation mesh for obstacle avoidance
	nav_mesh.cell_size = 0.25  # Smaller cells for better precision around obstacles
	nav_mesh.cell_height = 0.1
	nav_mesh.agent_height = 1.6
	nav_mesh.agent_radius = 0.3
	nav_mesh.agent_max_climb = 0.1
	nav_mesh.agent_max_slope = 45.0
	
	# Create vertices for the entire ground plane
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Ground plane covering the entire map
	vertices.append(Vector3(-1, 0, -1))      # Extend slightly beyond map bounds
	vertices.append(Vector3(50, 0, -1))
	vertices.append(Vector3(50, 0, 50))
	vertices.append(Vector3(-1, 0, 50))
	
	# Two triangles for the rectangle
	indices.append_array([0, 1, 2])
	indices.append_array([0, 2, 3])
	
	nav_mesh.vertices = vertices
	nav_mesh.polygons.clear()
	nav_mesh.add_polygon(indices)
	
	nav_region.navigation_mesh = nav_mesh
	
	# CRITICAL: Force navigation to account for all obstacles
	await get_tree().process_frame
	NavigationServer3D.map_force_update(nav_region.get_navigation_map())
	
	# Wait for obstacles to be processed
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Navigation region created - obstacles should now be avoided")
	
	# Debug: Print obstacle info
	print("=== OBSTACLE DEBUG ===")
	var all_obstacles = get_tree().get_nodes_in_group("navigation_obstacles")
	print("Found ", all_obstacles.size(), " navigation obstacles")


func debug_navigation_obstacles():
	print("=== NAVIGATION OBSTACLE DEBUG ===")
	
	# Find all NavigationObstacle3D nodes
	var obstacles = []
	find_navigation_obstacles_recursive(self, obstacles)
	
	print("Found ", obstacles.size(), " NavigationObstacle3D nodes:")
	for obstacle in obstacles:
		print("  - ", obstacle.get_parent().name, " at ", obstacle.global_position)
		print("    Radius: ", obstacle.radius, " Height: ", obstacle.height)
		print("    Enabled: ", not obstacle.is_disabled())
	
	# Check if navigation region can see them
	var nav_region = find_child("NavigationRegion") as NavigationRegion3D
	if nav_region:
		var nav_map = nav_region.get_navigation_map()
		print("Navigation map ID: ", nav_map)
		print("Map is valid: ", nav_map != RID())
	
func find_navigation_obstacles_recursive(node: Node, obstacles: Array):
	if node is NavigationObstacle3D:
		obstacles.append(node)
	for child in node.get_children():
		find_navigation_obstacles_recursive(child, obstacles)

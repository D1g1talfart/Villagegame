# Kitchen.gd - Updated to auto-convert and support eating
extends BuildableBuilding

@export var stored_crops: int = 0
@export var stored_meals: int = 0
@export var max_crops: int = 1
@export var max_meals: int = 10

func _ready():
	building_name = "Kitchen"
	building_size = Vector2i(3, 3)
	is_permanent = true 
	
	setup_collision()
	super._ready()
	setup_navigation_obstacle()
	
	# NO MORE KITCHEN WORKER JOB REGISTRATION!
	print("Kitchen ready - auto-converting crops to meals")
	
func setup_collision():
	collision_layer = 2
	collision_mask = 0

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	nav_obstacle.radius = 2.0
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(0, 0, 0)
	print("Kitchen navigation obstacle created")

func add_crops(amount: int) -> bool:
	if stored_crops + amount <= max_crops:
		stored_crops += amount
		print("Kitchen: Added ", amount, " crops. Total: ", stored_crops)
		
		# AUTO-CONVERT crops to meals immediately!
		auto_convert_crops()
		return true
	else:
		print("Kitchen: Cannot add crops - storage full!")
		return false

func auto_convert_crops():
	# Convert all available crops to meals (up to meal storage limit)
	while stored_crops > 0 and stored_meals < max_meals:
		stored_crops -= 1
		stored_meals += 1
		print("Kitchen: Auto-converted crop to meal. Crops: ", stored_crops, " Meals: ", stored_meals)

# NEW: Function for villagers to eat meals
func consume_meal() -> bool:
	if stored_meals > 0:
		stored_meals -= 1
		print("Kitchen: Villager consumed meal. Remaining meals: ", stored_meals)
		return true
	else:
		print("Kitchen: No meals available!")
		return false

func can_eat() -> bool:
	return stored_meals > 0

func is_kitchen() -> bool:
	return true

func get_work_position() -> Vector3:
	return global_position + Vector3(0, 0, -2.0)

func get_actual_work_spot() -> Vector3:
	return global_position

func can_accept_crops(amount: int) -> bool:
	return stored_crops + amount <= max_crops

func get_available_crop_space() -> int:
	return max_crops - stored_crops

func is_crops_storage_full() -> bool:
	return stored_crops >= max_crops

func get_storage_status() -> String:
	return "Crops: %d/%d, Meals: %d/%d" % [stored_crops, max_crops, stored_meals, max_meals]

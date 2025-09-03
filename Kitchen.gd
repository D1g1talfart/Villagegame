# Kitchen.gd
extends BuildableBuilding
class_name Kitchen

@export var stored_crops: int = 0
@export var stored_meals: int = 0
@export var max_crops: int = 10
@export var max_meals: int = 5

func _ready():
	building_name = "Kitchen"
	building_size = Vector2i(3, 3)
	
	# Kitchen doesn't have a mesh_instance like other buildings
	# Skip the super._ready() call that expects mesh_instance
	setup_navigation_obstacle()
	
	# Register kitchen job with JobManager AND set meta
	var kitchen_job = Job.new(Job.JobType.KITCHEN_WORKER, self)
	JobManager.register_job(kitchen_job)
	set_meta("job", kitchen_job)
	print("Kitchen job registered and meta set")
	
	
func setup_navigation_obstacle():
	# Add navigation obstacle so pathfinding goes around the kitchen
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	# For a 3x3 kitchen, use radius that covers the area
	nav_obstacle.radius = 2.0  # Slightly larger than half the diagonal of 3x3
	nav_obstacle.height = 1.0  # Height of the obstacle
	nav_obstacle.position = Vector3(0, 0, 0)  # Center of kitchen
	print("Kitchen navigation obstacle created with radius: ", nav_obstacle.radius)

func add_crops(amount: int) -> bool:
	if stored_crops + amount <= max_crops:
		stored_crops += amount
		print("Kitchen: Added ", amount, " crops. Total: ", stored_crops)
		return true
	else:
		print("Kitchen: Cannot add crops - storage full!")
		return false

func can_convert_crops() -> bool:
	return stored_crops > 0 and stored_meals < max_meals

func convert_crops_to_meals() -> bool:
	if can_convert_crops():
		stored_crops -= 1
		stored_meals += 1
		print("Kitchen: Converted crop to meal. Crops: ", stored_crops, " Meals: ", stored_meals)
		return true
	return false

func is_kitchen() -> bool:
	return true

func get_work_position() -> Vector3:
	# Pathfinding target - outside the 3x3 kitchen obstacle
	# Kitchen is 3x3, so we need to go outside the collision area
	return global_position + Vector3(0, 0, -2.0)  # 2 units south of kitchen center

func get_actual_work_spot() -> Vector3:
	# Actual work location - center of kitchen (for teleporting when working)
	return global_position

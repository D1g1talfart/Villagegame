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
	
	# Register kitchen job with JobManager AND set meta
	var kitchen_job = Job.new(Job.JobType.KITCHEN_WORKER, self)
	JobManager.register_job(kitchen_job)
	set_meta("job", kitchen_job)
	print("Kitchen job registered and meta set")

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
	# Pathfinding target - outside obstacle
	return global_position + Vector3(0.0, 0, 0)

func get_actual_work_spot() -> Vector3:
	# Actual work location - center of kitchen
	return global_position

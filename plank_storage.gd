# plank_storage.gd - Stores processed wood planks
extends BuildableBuilding

@export var stored_planks: int = 0
@export var max_planks: int = 50  # Higher capacity than raw wood since planks are processed
@export var building_level: int = 1

func _ready():
	building_name = "Plank Storage"
	building_size = Vector2i(2, 3)  # Slightly larger than regular storage
	super._ready()
	
	add_to_group("plank_storage")
	setup_navigation_obstacle()
	
	print("Plank Storage ready - Capacity: ", max_planks, " planks")

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 1.5
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1, 0, 1.5)  # Center of 2x3 building
	print("Plank Storage navigation obstacle created")

# Plank storage functions
func add_planks(amount: int) -> bool:
	if stored_planks + amount <= max_planks:
		stored_planks += amount
		print("Plank Storage: Added ", amount, " planks. Total: ", stored_planks, "/", max_planks)
		return true
	else:
		print("Plank Storage: Cannot add planks - storage full!")
		return false

func can_accept_planks(amount: int) -> bool:
	return stored_planks + amount <= max_planks

func get_available_plank_space() -> int:
	return max_planks - stored_planks

func is_plank_storage_full() -> bool:
	return stored_planks >= max_planks

func remove_planks(amount: int) -> bool:
	if stored_planks >= amount:
		stored_planks -= amount
		print("Plank Storage: Removed ", amount, " planks. Remaining: ", stored_planks, "/", max_planks)
		return true
	else:
		print("Plank Storage: Not enough planks to remove!")
		return false

func get_stored_planks() -> int:
	return stored_planks

func has_planks(amount: int) -> bool:
	return stored_planks >= amount

func get_storage_status() -> String:
	return "Planks: %d/%d" % [stored_planks, max_planks]

# Work positions
func get_work_position() -> Vector3:
	return global_position + Vector3(2.0, 0, 1.5)  # East side of 2x3 building

func get_actual_work_spot() -> Vector3:
	return global_position + Vector3(1, 0, 1.5)  # Center of 2x3 building

# Identify as plank storage
func is_plank_storage() -> bool:
	return true

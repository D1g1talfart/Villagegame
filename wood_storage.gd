# WoodStorage.gd - 2x2 wood storage building
extends BuildableBuilding

@export var stored_wood: int = 0
@export var max_wood: int = 10
@export var building_level: int = 1

var work_positions: Array[Vector3] = []

func _ready():
	building_name = "Wood Storage"
	building_size = Vector2i(2, 2)
	super._ready()
	
	setup_work_positions()
	setup_navigation_obstacle()
	
	print("Wood Storage ready - Capacity: ", max_wood, " wood")

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 1.5  # For 2x2 building
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1, 0, 1)  # Center of 2x2
	print("Wood Storage navigation obstacle created")

func setup_work_positions():
	var obstacle_center = Vector3(1, 0, 1)  # Center of 2x2
	work_positions = [
		obstacle_center + Vector3(1.0, 0, 0),    # East side
		obstacle_center + Vector3(-1.0, 0, 0),   # West side  
		obstacle_center + Vector3(0, 0, 1.0),    # South side
		obstacle_center + Vector3(0, 0, -1.0)    # North side
	]

func get_work_position() -> Vector3:
	if work_positions.is_empty():
		return global_position + Vector3(2.0, 0, 0)
	return global_position + work_positions[0]  # East side

func get_actual_work_spot() -> Vector3:
	return global_position + Vector3(1, 0, 1)  # Center of 2x2

func add_wood(amount: int) -> bool:
	if stored_wood + amount <= max_wood:
		stored_wood += amount
		print("Wood Storage: Added ", amount, " wood. Total: ", stored_wood, "/", max_wood)
		return true
	else:
		print("Wood Storage: Cannot add wood - storage full!")
		return false

func can_accept_wood(amount: int) -> bool:
	return stored_wood + amount <= max_wood

func get_available_wood_space() -> int:
	return max_wood - stored_wood

func is_wood_storage_full() -> bool:
	return stored_wood >= max_wood

func is_wood_storage() -> bool:
	return true

func get_storage_status() -> String:
	return "Wood: %d/%d" % [stored_wood, max_wood]

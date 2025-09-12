# stone_storage.gd - 2x2 stone storage building
extends BuildableBuilding

@export var stored_stone: int = 0
@export var max_stone: int = 10
@export var building_level: int = 1

var work_positions: Array[Vector3] = []

func _ready():
	building_name = "Stone Storage"
	building_size = Vector2i(2, 2)
	super._ready()
	
	add_to_group("stone_storage")
	
	setup_work_positions()
	setup_navigation_obstacle()
	
	print("Stone Storage ready - Capacity: ", max_stone, " stone")

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 1.5  # For 2x2 building
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1, 0, 1)  # Center of 2x2
	print("Stone Storage navigation obstacle created")

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

func add_stone(amount: int) -> bool:
	if stored_stone + amount <= max_stone:
		stored_stone += amount
		print("Stone Storage: Added ", amount, " stone. Total: ", stored_stone, "/", max_stone)
		return true
	else:
		print("Stone Storage: Cannot add stone - storage full!")
		return false

func can_accept_stone(amount: int) -> bool:
	return stored_stone + amount <= max_stone

func get_available_stone_space() -> int:
	return max_stone - stored_stone

func is_stone_storage_full() -> bool:
	return stored_stone >= max_stone

func is_stone_storage() -> bool:
	return true

func get_storage_status() -> String:
	return "Stone: %d/%d" % [stored_stone, max_stone]

func remove_stone(amount: int) -> bool:
	if stored_stone >= amount:
		stored_stone -= amount
		print("Stone Storage: Removed ", amount, " stone. Remaining: ", stored_stone, "/", max_stone)
		return true
	else:
		print("Stone Storage: Not enough stone to remove!")
		return false

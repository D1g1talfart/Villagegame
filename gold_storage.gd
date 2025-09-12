# gold_storage.gd - 2x2 gold storage building
extends BuildableBuilding

@export var stored_gold: int = 0
@export var max_gold: int = 1000  # Higher capacity since gold is the main currency
@export var building_level: int = 1

func _ready():
	building_name = "Gold Storage"
	building_size = Vector2i(2, 2)
	super._ready()
	
	add_to_group("gold_storage")  # Important for BuildingShop to find it
	
	setup_navigation_obstacle()
	
	print("Gold Storage ready - Capacity: ", max_gold, " gold")

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 1.5  # For 2x2 building
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1, 0, 1)  # Center of 2x2
	print("Gold Storage navigation obstacle created")

func add_gold(amount: int) -> bool:
	if stored_gold + amount <= max_gold:
		stored_gold += amount
		print("Gold Storage: Added ", amount, " gold. Total: ", stored_gold, "/", max_gold)
		return true
	else:
		print("Gold Storage: Cannot add gold - storage full!")
		return false

func can_accept_gold(amount: int) -> bool:
	return stored_gold + amount <= max_gold

func get_available_gold_space() -> int:
	return max_gold - stored_gold

func is_gold_storage_full() -> bool:
	return stored_gold >= max_gold

func is_gold_storage() -> bool:
	return true

func get_storage_status() -> String:
	return "Gold: %d/%d" % [stored_gold, max_gold]

func remove_gold(amount: int) -> bool:
	if stored_gold >= amount:
		stored_gold -= amount
		print("Gold Storage: Removed ", amount, " gold. Remaining: ", stored_gold, "/", max_gold)
		return true
	else:
		print("Gold Storage: Not enough gold to remove!")
		return false

# Helper function to get current gold (used by BuildingShop)
func get_stored_gold() -> int:
	return stored_gold

# Helper function to check if we have enough gold
func has_gold(amount: int) -> bool:
	return stored_gold >= amount

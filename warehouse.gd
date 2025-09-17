# warehouse.gd - Trade goods storage with upgrade system
extends BuildableBuilding

# Trade goods storage - using dictionaries to store multiple item types
@export var stored_items: Dictionary = {
	"fur_tufts": 0,
	"fur_charm": 0,
	"noble_trinket": 0
}

@export var max_items: Dictionary = {
	"fur_tufts": 10,
	"fur_charm": 5,
	"noble_trinket": 5
}

@export var building_level: int = 1

# Upgrade system - only 2 levels for warehouse
var upgrade_data: Dictionary = {
	2: { "cost_gold": 800, "cost_wood": 20, "cost_stone": 30, "max_capacity_multiplier": 2 }
}

var is_upgrading: bool = false
var upgrade_resources_needed: Dictionary = {}
var upgrade_resources_delivered: Dictionary = {}

func _ready():
	building_name = "Warehouse"
	building_size = Vector2i(3, 2)  # Larger than gold storage
	super._ready()
	
	add_to_group("warehouse")
	update_capacity_for_level()
	setup_navigation_obstacle()
	
	print("Warehouse ready - Level: ", building_level, " Capacities: ", max_items)

func update_capacity_for_level():
	match building_level:
		1:
			max_items = {
				"fur_tufts": 10,
				"fur_charm": 5,
				"noble_trinket": 5
			}
		2:
			max_items = {
				"fur_tufts": 20,
				"fur_charm": 10,
				"noble_trinket": 10
			}
func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 2.0  # Larger since warehouse is 3x2
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1.5, 0, 1)  # Center of 3x2 building
	print("Warehouse navigation obstacle created")

# Upgrade system functions
func can_upgrade() -> bool:
	return building_level < 2 and not is_upgrading  # Only 2 levels

func get_upgrade_cost() -> Dictionary:
	var next_level = building_level + 1
	if upgrade_data.has(next_level):
		return upgrade_data[next_level]
	return {}

func start_upgrade() -> bool:
	if not can_upgrade():
		return false
	
	var upgrade_cost = get_upgrade_cost()
	if upgrade_cost.is_empty():
		return false
	
	# Check if we can afford the upgrade
	var gold_storage = find_gold_storage()
	var wood_storage = find_wood_storage()
	var stone_storage = find_stone_storage()
	
	var has_gold = gold_storage and gold_storage.stored_gold >= upgrade_cost.get("cost_gold", 0)
	var has_wood = wood_storage and wood_storage.stored_wood >= upgrade_cost.get("cost_wood", 0)
	var has_stone = stone_storage and stone_storage.stored_stone >= upgrade_cost.get("cost_stone", 0)
	
	if not (has_gold and has_wood and has_stone):
		print("Not enough resources for warehouse upgrade!")
		return false
	
	# Deduct gold immediately
	gold_storage.remove_gold(upgrade_cost.get("cost_gold", 0))
	
	# Set up upgrade state
	is_upgrading = true
	upgrade_resources_needed = {
		"wood": upgrade_cost.get("cost_wood", 0),
		"stone": upgrade_cost.get("cost_stone", 0)
	}
	upgrade_resources_delivered = {
		"wood": 0,
		"stone": 0
	}
	
	# Create builder job
	var builder_job = Job.new(Job.JobType.BUILDER, self)
	JobManager.register_job(builder_job)
	
	print("Started warehouse upgrade to level ", building_level + 1)
	print("Need: ", upgrade_resources_needed)
	
	return true

func deliver_upgrade_resource(resource_type: String, amount: int = 1):
	if not is_upgrading:
		return
	
	if upgrade_resources_delivered.has(resource_type):
		upgrade_resources_delivered[resource_type] += amount
		print("Delivered ", amount, " ", resource_type, " to warehouse upgrade")
		print("Progress: ", upgrade_resources_delivered)
		
		check_upgrade_completion()

func check_upgrade_completion():
	var wood_complete = upgrade_resources_delivered["wood"] >= upgrade_resources_needed["wood"]
	var stone_complete = upgrade_resources_delivered["stone"] >= upgrade_resources_needed["stone"]
	
	if wood_complete and stone_complete:
		complete_upgrade()

func complete_upgrade():
	building_level += 1
	is_upgrading = false
	update_capacity_for_level()
	
	# Clear upgrade data
	upgrade_resources_needed.clear()
	upgrade_resources_delivered.clear()
	
	# Remove builder job
	var builder_jobs = JobManager.get_jobs_by_type(Job.JobType.BUILDER)
	for job in builder_jobs:
		if job.workplace == self:
			JobManager.unregister_job(job)
			break
	
	print("Warehouse upgraded to level ", building_level, "! New capacities: ", max_items)

func get_upgrade_info() -> String:
	if not can_upgrade():
		if building_level >= 2:
			return "Max Level Reached"
		elif is_upgrading:
			return "Upgrading... (%d/%d wood, %d/%d stone)" % [
				upgrade_resources_delivered.get("wood", 0),
				upgrade_resources_needed.get("wood", 0),
				upgrade_resources_delivered.get("stone", 0), 
				upgrade_resources_needed.get("stone", 0)
			]
	
	var cost = get_upgrade_cost()
	if not cost.is_empty():
		return "Upgrade to Level %d: %d gold, %d wood, %d stone" % [
			building_level + 1,
			cost.get("cost_gold", 0),
			cost.get("cost_wood", 0),
			cost.get("cost_stone", 0)
		]
	
	return "Cannot Upgrade"

# Trade goods storage functions
func add_trade_good(item_type: String, amount: int = 1) -> bool:
	if not stored_items.has(item_type) or not max_items.has(item_type):
		print("Warehouse: Unknown item type: ", item_type)
		return false
	
	if stored_items[item_type] + amount <= max_items[item_type]:
		stored_items[item_type] += amount
		print("Warehouse: Added ", amount, " ", item_type, ". Total: ", stored_items[item_type], "/", max_items[item_type])
		return true
	else:
		print("Warehouse: Cannot add ", item_type, " - storage full!")
		return false

func can_accept_trade_good(item_type: String, amount: int = 1) -> bool:
	if not stored_items.has(item_type) or not max_items.has(item_type):
		return false
	return stored_items[item_type] + amount <= max_items[item_type]

func get_available_space(item_type: String) -> int:
	if not stored_items.has(item_type) or not max_items.has(item_type):
		return 0
	return max_items[item_type] - stored_items[item_type]

func is_storage_full(item_type: String) -> bool:
	if not stored_items.has(item_type) or not max_items.has(item_type):
		return true
	return stored_items[item_type] >= max_items[item_type]

func remove_trade_good(item_type: String, amount: int = 1) -> bool:
	if not stored_items.has(item_type):
		print("Warehouse: Unknown item type: ", item_type)
		return false
	
	if stored_items[item_type] >= amount:
		stored_items[item_type] -= amount
		print("Warehouse: Removed ", amount, " ", item_type, ". Remaining: ", stored_items[item_type], "/", max_items[item_type])
		return true
	else:
		print("Warehouse: Not enough ", item_type, " to remove!")
		return false

func has_trade_good(item_type: String, amount: int = 1) -> bool:
	if not stored_items.has(item_type):
		return false
	return stored_items[item_type] >= amount

func get_stored_amount(item_type: String) -> int:
	return stored_items.get(item_type, 0)

func get_storage_status() -> String:
	var status_parts = []
	for item_type in stored_items.keys():
		var display_name = item_type.replace("_", " ").capitalize()
		status_parts.append("%s: %d/%d" % [display_name, stored_items[item_type], max_items[item_type]])
	
	var items_status = " | ".join(status_parts)
	
	if is_upgrading:
		return "%s (Upgrading to Level %d)" % [items_status, building_level + 1]
	else:
		return "%s (Level %d)" % [items_status, building_level]

# Helper functions to find storage buildings
func find_gold_storage():
	var gold_storages = get_tree().get_nodes_in_group("gold_storage")
	return gold_storages[0] if gold_storages.size() > 0 else null

func find_wood_storage():
	var wood_storages = get_tree().get_nodes_in_group("wood_storage")
	return wood_storages[0] if wood_storages.size() > 0 else null

func find_stone_storage():
	var stone_storages = get_tree().get_nodes_in_group("stone_storage")
	return stone_storages[0] if stone_storages.size() > 0 else null

# Work position for builders
func get_work_position() -> Vector3:
	return global_position + Vector3(3.0, 0, 0)  # East side of 3x2 building

func get_actual_work_spot() -> Vector3:
	return global_position + Vector3(1.5, 0, 1)  # Center of 3x2 building

# Identify as warehouse
func is_warehouse() -> bool:
	return true

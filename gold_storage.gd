# gold_storage.gd - Updated with upgrade system
extends BuildableBuilding

@export var stored_gold: int = 0
@export var max_gold: int = 1000
@export var building_level: int = 1

# Upgrade system
var upgrade_data: Dictionary = {
	2: { "cost_gold": 500, "cost_wood": 10, "cost_stone": 20, "max_capacity": 2500 },
	3: { "cost_gold": 1500, "cost_wood": 40, "cost_stone": 40, "max_capacity": 5000 }
}

var is_upgrading: bool = false
var upgrade_resources_needed: Dictionary = {}
var upgrade_resources_delivered: Dictionary = {}

func _ready():
	building_name = "Gold Storage"
	building_size = Vector2i(2, 2)
	super._ready()
	
	add_to_group("gold_storage")
	update_capacity_for_level()
	setup_navigation_obstacle()
	
	print("Gold Storage ready - Level: ", building_level, " Capacity: ", max_gold, " gold")

func update_capacity_for_level():
	match building_level:
		1: max_gold = 1000
		2: max_gold = 2500  
		3: max_gold = 5000

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 1.5
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1, 0, 1)
	print("Gold Storage navigation obstacle created")

# Upgrade system functions
func can_upgrade() -> bool:
	return building_level < 3 and not is_upgrading

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
	var gold_storage = self  # We are the gold storage
	var wood_storage = find_wood_storage()
	var stone_storage = find_stone_storage()
	
	var has_gold = gold_storage.stored_gold >= upgrade_cost.get("cost_gold", 0)
	var has_wood = wood_storage and wood_storage.stored_wood >= upgrade_cost.get("cost_wood", 0)
	var has_stone = stone_storage and stone_storage.stored_stone >= upgrade_cost.get("cost_stone", 0)
	
	if not (has_gold and has_wood and has_stone):
		print("Not enough resources for upgrade!")
		return false
	
	# Deduct gold immediately (since we are the gold storage)
	remove_gold(upgrade_cost.get("cost_gold", 0))
	
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
	
	print("Started upgrade to level ", building_level + 1)
	print("Need: ", upgrade_resources_needed)
	
	return true

func deliver_upgrade_resource(resource_type: String, amount: int = 1):
	if not is_upgrading:
		return
	
	if upgrade_resources_delivered.has(resource_type):
		upgrade_resources_delivered[resource_type] += amount
		print("Delivered ", amount, " ", resource_type, " to gold storage upgrade")
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
	
	print("Gold Storage upgraded to level ", building_level, "! New capacity: ", max_gold)

func get_upgrade_info() -> String:
	if not can_upgrade():
		if building_level >= 3:
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

# Helper functions to find storage buildings
func find_wood_storage():
	var wood_storages = get_tree().get_nodes_in_group("wood_storage")
	return wood_storages[0] if wood_storages.size() > 0 else null

func find_stone_storage():
	var stone_storages = get_tree().get_nodes_in_group("stone_storage")
	return stone_storages[0] if stone_storages.size() > 0 else null

# Work position for builders
func get_work_position() -> Vector3:
	return global_position + Vector3(2.0, 0, 0)  # East side

func get_actual_work_spot() -> Vector3:
	return global_position + Vector3(1, 0, 1)  # Center

# Original gold storage functions (unchanged)
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
	if is_upgrading:
		return "Gold: %d/%d (Upgrading to Level %d)" % [stored_gold, max_gold, building_level + 1]
	else:
		return "Gold: %d/%d (Level %d)" % [stored_gold, max_gold, building_level]

func remove_gold(amount: int) -> bool:
	if stored_gold >= amount:
		stored_gold -= amount
		print("Gold Storage: Removed ", amount, " gold. Remaining: ", stored_gold, "/", max_gold)
		return true
	else:
		print("Gold Storage: Not enough gold to remove!")
		return false

func get_stored_gold() -> int:
	return stored_gold

func has_gold(amount: int) -> bool:
	return stored_gold >= amount

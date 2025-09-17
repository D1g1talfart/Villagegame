# ornament_workshop.gd - Crafts ornaments from wood, stone, and fur tufts
extends BuildableBuilding

enum RecipeType { FUR_CHARM, NOBLE_TRINKET }

@export var selected_recipe: RecipeType = RecipeType.FUR_CHARM
@export var building_level: int = 1
@export var is_crafting: bool = false
@export var crafting_timer: float = 0.0

# Recipe definitions
var recipes: Dictionary = {
	RecipeType.FUR_CHARM: {
		"name": "Fur Charm",
		"display_name": "Fur Charm",
		"fur_tufts": 1,
		"wood": 1,
		"stone": 0,
		"craft_time": 600.0,  # 10 minutes
		"output_item": "fur_charm"
	},
	RecipeType.NOBLE_TRINKET: {
		"name": "Noble Trinket",
		"display_name": "Noble Trinket", 
		"fur_tufts": 2,
		"wood": 2,
		"stone": 1,
		"craft_time": 600.0,  # 10 minutes
		"output_item": "noble_trinket"
	}
}

var assigned_villager = null
var resources_collected: Dictionary = {
	"fur_tufts": 0,
	"wood": 0,
	"stone": 0
}

var crafting_timer_node: Timer

func _ready():
	building_name = "Ornament Workshop"
	building_size = Vector2i(2, 2)
	super._ready()
	
	add_to_group("ornament_workshop")
	setup_navigation_obstacle()
	setup_crafting_timer()
	create_crafter_job()
	
	print("Ornament Workshop ready - Selected recipe: ", recipes[selected_recipe]["display_name"])

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 1.5
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1, 0, 1)
	print("Ornament Workshop navigation obstacle created")

func setup_crafting_timer():
	crafting_timer_node = Timer.new()
	crafting_timer_node.name = "CraftingTimer"
	crafting_timer_node.one_shot = true
	crafting_timer_node.timeout.connect(_on_crafting_complete)
	add_child(crafting_timer_node)

func create_crafter_job():
	if not has_crafter_job():
		var crafter_job = Job.new(Job.JobType.ORNAMENT_CRAFTER, self)
		JobManager.register_job(crafter_job)
		print("Ornament Workshop: Created ornament crafter job")

func has_crafter_job() -> bool:
	var crafter_jobs = JobManager.get_jobs_by_type(Job.JobType.ORNAMENT_CRAFTER)
	for job in crafter_jobs:
		if job.workplace == self:
			return true
	return false

func remove_crafter_job():
	var crafter_jobs = JobManager.get_jobs_by_type(Job.JobType.ORNAMENT_CRAFTER)
	for job in crafter_jobs:
		if job.workplace == self:
			JobManager.unregister_job(job)
			print("Ornament Workshop: Removed ornament crafter job")
			break

# Recipe management
func set_selected_recipe(recipe: RecipeType):
	if not is_crafting:
		selected_recipe = recipe
		print("Ornament Workshop: Recipe changed to ", recipes[selected_recipe]["display_name"])
		# Reset collected resources when recipe changes
		resources_collected = {"fur_tufts": 0, "wood": 0, "stone": 0}
	else:
		print("Ornament Workshop: Cannot change recipe while crafting!")

func get_selected_recipe() -> Dictionary:
	return recipes[selected_recipe]

func get_recipe_display_name() -> String:
	return recipes[selected_recipe]["display_name"]

# Resource requirement checks
func can_craft_selected_recipe() -> bool:
	var recipe = get_selected_recipe()
	
	# Check warehouse for fur tufts
	var warehouse = find_warehouse()
	var has_tufts = warehouse and warehouse.has_trade_good("fur_tufts", recipe["fur_tufts"])
	
	# Check wood storage
	var wood_storage = find_wood_storage()
	var has_wood = wood_storage and wood_storage.has_wood(recipe["wood"])
	
	# Check stone storage (if needed)
	var has_stone = true
	if recipe["stone"] > 0:
		var stone_storage = find_stone_storage()
		has_stone = stone_storage and stone_storage.has_stone(recipe["stone"])
	
	# Check warehouse has space for output
	var has_output_space = warehouse and warehouse.can_accept_trade_good(recipe["output_item"], 1)
	
	return has_tufts and has_wood and has_stone and has_output_space

func get_needed_resources() -> Dictionary:
	var recipe = get_selected_recipe()
	return {
		"wood": max(0, recipe["wood"] - resources_collected["wood"]),
		"stone": max(0, recipe["stone"] - resources_collected["stone"])
		# Tufts are auto-pulled when crafting starts
	}

# Resource collection by villager
func deliver_resource(resource_type: String, amount: int = 1):
	if resource_type in resources_collected:
		resources_collected[resource_type] += amount
		print("Ornament Workshop: Received ", amount, " ", resource_type, ". Total: ", resources_collected[resource_type])
		
		check_ready_to_craft()

func check_ready_to_craft():
	if is_crafting:
		return
		
	var recipe = get_selected_recipe()
	var wood_ready = resources_collected["wood"] >= recipe["wood"]
	var stone_ready = resources_collected["stone"] >= recipe["stone"]
	
	if wood_ready and stone_ready:
		start_crafting()

# Crafting process
func start_crafting():
	if is_crafting:
		return false
		
	var recipe = get_selected_recipe()
	
	# Auto-pull fur tufts from warehouse
	var warehouse = find_warehouse()
	if not warehouse or not warehouse.has_trade_good("fur_tufts", recipe["fur_tufts"]):
		print("Ornament Workshop: Cannot start crafting - not enough fur tufts in warehouse")
		return false
	
	if not warehouse.remove_trade_good("fur_tufts", recipe["fur_tufts"]):
		print("Ornament Workshop: Failed to remove fur tufts from warehouse")
		return false
	
	# Check warehouse has space for output
	if not warehouse.can_accept_trade_good(recipe["output_item"], 1):
		print("Ornament Workshop: Cannot start crafting - warehouse full for output item")
		# Return the tufts we just removed
		warehouse.add_trade_good("fur_tufts", recipe["fur_tufts"])
		return false
	
	# Start crafting
	is_crafting = true
	resources_collected["fur_tufts"] = recipe["fur_tufts"]  # Mark as collected
	crafting_timer_node.wait_time = recipe["craft_time"]
	crafting_timer_node.start()
	
	print("Ornament Workshop: Started crafting ", recipe["display_name"], " (", recipe["craft_time"], " seconds)")
	return true

func _on_crafting_complete():
	var recipe = get_selected_recipe()
	var warehouse = find_warehouse()
	
	if warehouse and warehouse.add_trade_good(recipe["output_item"], 1):
		print("Ornament Workshop: Crafted and stored 1 ", recipe["display_name"])
		
		# Reset for next craft
		is_crafting = false
		resources_collected = {"fur_tufts": 0, "wood": 0, "stone": 0}
		
		# Notify villager that crafting is complete
		if assigned_villager:
			print("Ornament Workshop: Notifying villager that crafting is complete")
	else:
		print("Ornament Workshop: Crafting complete but cannot store in warehouse!")
		# This shouldn't happen since we checked space before starting
		is_crafting = false
		resources_collected = {"fur_tufts": 0, "wood": 0, "stone": 0}

# Job assignment
func assign_villager(villager):
	if assigned_villager:
		return false
	
	assigned_villager = villager
	print("Ornament Workshop: Assigned villager for crafting")
	return true

func remove_villager():
	if assigned_villager:
		assigned_villager = null
		print("Ornament Workshop: Removed villager")

func has_assigned_villager() -> bool:
	return assigned_villager != null

# Status and display
func get_crafting_status() -> String:
	var recipe = get_selected_recipe()
	var status = "Recipe: " + recipe["display_name"]
	
	if is_crafting:
		var time_left = crafting_timer_node.time_left
		status += " | Crafting: %d sec" % int(time_left)
	else:
		var needed = get_needed_resources()
		if needed["wood"] > 0 or needed["stone"] > 0:
			status += " | Need:"
			if needed["wood"] > 0:
				status += " %dW" % needed["wood"]
			if needed["stone"] > 0:
				status += " %dS" % needed["stone"]
		else:
			status += " | Ready to craft"
	
	return status

# Work positions
func get_work_position() -> Vector3:
	return global_position + Vector3(2.0, 0, 1.0)  # East side

func get_actual_work_spot() -> Vector3:
	return global_position + Vector3(1, 0, 1)  # Center

# Helper functions
func find_warehouse():
	var warehouses = get_tree().get_nodes_in_group("warehouse")
	return warehouses[0] if warehouses.size() > 0 else null

func find_wood_storage():
	var wood_storages = get_tree().get_nodes_in_group("wood_storage")
	return wood_storages[0] if wood_storages.size() > 0 else null

func find_stone_storage():
	var stone_storages = get_tree().get_nodes_in_group("stone_storage")
	return stone_storages[0] if stone_storages.size() > 0 else null

# Identify building type
func is_ornament_workshop() -> bool:
	return true

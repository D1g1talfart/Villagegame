# plank_workshop.gd - Converts wood into planks
extends BuildableBuilding

@export var building_level: int = 1
@export var is_crafting: bool = false

# Plank recipe - simple conversion
var plank_recipe: Dictionary = {
	"name": "Wood Plank",
	"wood_cost": 1,        # 1 wood per plank
	"craft_time": 120.0,   # 2 minutes per plank
	"output_planks": 1
}

var assigned_villager = null
var wood_collected: int = 0
var crafting_timer_node: Timer

func _ready():
	building_name = "Plank Workshop"
	building_size = Vector2i(2, 2)
	super._ready()
	
	add_to_group("plank_workshop")
	setup_navigation_obstacle()
	setup_crafting_timer()
	create_plank_worker_job()
	
	print("Plank Workshop ready")

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 1.5
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1, 0, 1)
	print("Plank Workshop navigation obstacle created")

func setup_crafting_timer():
	crafting_timer_node = Timer.new()
	crafting_timer_node.name = "CraftingTimer"
	crafting_timer_node.one_shot = true
	crafting_timer_node.timeout.connect(_on_crafting_complete)
	add_child(crafting_timer_node)

func create_plank_worker_job():
	if not has_plank_worker_job():
		var plank_job = Job.new(Job.JobType.PLANK_WORKER, self)
		JobManager.register_job(plank_job)
		print("Plank Workshop: Created plank worker job")

func has_plank_worker_job() -> bool:
	var plank_jobs = JobManager.get_jobs_by_type(Job.JobType.PLANK_WORKER)
	for job in plank_jobs:
		if job.workplace == self:
			return true
	return false

func remove_plank_worker_job():
	var plank_jobs = JobManager.get_jobs_by_type(Job.JobType.PLANK_WORKER)
	for job in plank_jobs:
		if job.workplace == self:
			JobManager.unregister_job(job)
			print("Plank Workshop: Removed plank worker job")
			break

# Crafting logic
func can_craft_planks() -> bool:
	# Check wood storage has wood
	var wood_storage = find_wood_storage()
	var has_wood = wood_storage and wood_storage.has_wood(plank_recipe["wood_cost"])
	
	# Check plank storage has space
	var plank_storage = find_plank_storage()
	var has_space = plank_storage and plank_storage.can_accept_planks(plank_recipe["output_planks"])
	
	return has_wood and has_space and not is_crafting

func get_needed_wood() -> int:
	return max(0, plank_recipe["wood_cost"] - wood_collected)

func deliver_wood(amount: int = 1):
	wood_collected += amount
	print("Plank Workshop: Received ", amount, " wood. Total: ", wood_collected)
	
	if wood_collected >= plank_recipe["wood_cost"]:
		start_crafting()

func start_crafting():
	if is_crafting or wood_collected < plank_recipe["wood_cost"]:
		return false
	
	# Check plank storage has space
	var plank_storage = find_plank_storage()
	if not plank_storage or not plank_storage.can_accept_planks(plank_recipe["output_planks"]):
		print("Plank Workshop: Cannot start crafting - plank storage full")
		return false
	
	is_crafting = true
	crafting_timer_node.wait_time = plank_recipe["craft_time"]
	crafting_timer_node.start()
	
	print("Plank Workshop: Started crafting planks (", plank_recipe["craft_time"], " seconds)")
	return true

func _on_crafting_complete():
	print("Plank Workshop: Crafting complete - ", plank_recipe["output_planks"], " planks ready")
	is_crafting = false
	wood_collected = 0  # Reset wood counter
	
	# Notify villager that planks are ready to collect
	if assigned_villager:
		print("Plank Workshop: Notifying villager that planks are ready")

func collect_finished_planks() -> int:
	if is_crafting:
		return 0
	
	# This function is called when villager picks up finished planks
	var planks_to_give = plank_recipe["output_planks"]
	print("Plank Workshop: Villager collected ", planks_to_give, " planks")
	return planks_to_give

func has_finished_planks() -> bool:
	return not is_crafting and wood_collected == 0  # Crafting done, wood consumed

# Job assignment
func assign_villager(villager):
	if assigned_villager:
		return false
	
	assigned_villager = villager
	print("Plank Workshop: Assigned villager")
	return true

func remove_villager():
	if assigned_villager:
		assigned_villager = null
		print("Plank Workshop: Removed villager")

func has_assigned_villager() -> bool:
	return assigned_villager != null

# Status and display
func get_crafting_status() -> String:
	if is_crafting:
		var time_left = crafting_timer_node.time_left
		return "Crafting planks: %d sec" % int(time_left)
	elif has_finished_planks():
		return "Planks ready for pickup"
	elif wood_collected < plank_recipe["wood_cost"]:
		return "Need %d wood" % get_needed_wood()
	else:
		return "Ready to craft"

# Work positions
func get_work_position() -> Vector3:
	return global_position + Vector3(2.0, 0, 1.0)  # East side

func get_actual_work_spot() -> Vector3:
	return global_position + Vector3(1, 0, 1)  # Center

# Helper functions
func find_wood_storage():
	var wood_storages = get_tree().get_nodes_in_group("wood_storage")
	return wood_storages[0] if wood_storages.size() > 0 else null

func find_plank_storage():
	var plank_storages = get_tree().get_nodes_in_group("plank_storage")
	return plank_storages[0] if plank_storages.size() > 0 else null

# Identify building type
func is_plank_workshop() -> bool:
	return true

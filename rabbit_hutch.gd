# rabbit_hutch.gd - Produces Fur Tufts passively and with assigned workers
extends BuildableBuilding

@export var stored_fur_tufts: int = 0
@export var max_storage: int = 5  # Internal storage capacity
@export var building_level: int = 1

# Production timers
var passive_production_timer: Timer
var worker_production_timer: Timer

# Production settings (in seconds)
const PASSIVE_PRODUCTION_TIME: float = 300.0  # 5 minutes
const WORKER_PRODUCTION_TIME: float = 60.0    # 1 minute

var assigned_villager = null
var is_producing: bool = true

# Call this in _ready() to make the job available
func _ready():
	building_name = "Rabbit Hutch"
	building_size = Vector2i(2, 2)
	super._ready()
	
	add_to_group("rabbit_hutch")
	setup_production_timers()
	setup_navigation_obstacle()
	start_passive_production()
	create_rabbit_handler_job()  # Make job available for assignment
	
	print("Rabbit Hutch ready - Storage: ", stored_fur_tufts, "/", max_storage)

func setup_production_timers():
	# Passive production timer
	passive_production_timer = Timer.new()
	passive_production_timer.name = "PassiveProductionTimer"
	passive_production_timer.wait_time = PASSIVE_PRODUCTION_TIME
	passive_production_timer.one_shot = false
	passive_production_timer.timeout.connect(_on_passive_production_complete)
	add_child(passive_production_timer)
	
	# Worker production timer
	worker_production_timer = Timer.new()
	worker_production_timer.name = "WorkerProductionTimer"
	worker_production_timer.wait_time = WORKER_PRODUCTION_TIME
	worker_production_timer.one_shot = false
	worker_production_timer.timeout.connect(_on_worker_production_complete)
	add_child(worker_production_timer)

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 1.5
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1, 0, 1)
	print("Rabbit Hutch navigation obstacle created")

func start_passive_production():
	if not assigned_villager and can_produce_internally():
		passive_production_timer.start()
		print("Rabbit Hutch: Started passive production")

func stop_passive_production():
	passive_production_timer.stop()

func can_produce_internally() -> bool:
	return stored_fur_tufts < max_storage

func can_send_to_warehouse() -> bool:
	var warehouse = find_warehouse()
	return warehouse and warehouse.can_accept_trade_good("fur_tufts", 1)

# Passive production (stores internally)
func _on_passive_production_complete():
	if can_produce_internally():
		stored_fur_tufts += 1
		print("Rabbit Hutch: Passive production complete! Stored: ", stored_fur_tufts, "/", max_storage)
		
		# Stop production if storage is full
		if stored_fur_tufts >= max_storage:
			stop_passive_production()
			print("Rabbit Hutch: Internal storage full - passive production stopped")
	else:
		stop_passive_production()

# Worker production (sends directly to warehouse)
func _on_worker_production_complete():
	if assigned_villager and can_send_to_warehouse():
		var warehouse = find_warehouse()
		if warehouse and warehouse.add_trade_good("fur_tufts", 1):
			print("Rabbit Hutch: Worker produced and delivered 1 Fur Tuft to warehouse")
		else:
			print("Rabbit Hutch: Worker production failed - warehouse full or missing")

# Manual collection by player (transfer all stored tufts to warehouse)
func collect_stored_tufts() -> bool:
	if stored_fur_tufts <= 0:
		print("Rabbit Hutch: No fur tufts to collect")
		return false
	
	var warehouse = find_warehouse()
	if not warehouse:
		print("Rabbit Hutch: No warehouse found!")
		return false
	
	var amount_to_transfer = stored_fur_tufts
	var space_available = warehouse.get_available_space("fur_tufts")
	var actual_transfer = min(amount_to_transfer, space_available)
	
	if actual_transfer <= 0:
		print("Rabbit Hutch: Warehouse has no space for fur tufts")
		return false
	
	if warehouse.add_trade_good("fur_tufts", actual_transfer):
		stored_fur_tufts -= actual_transfer
		print("Rabbit Hutch: Transferred ", actual_transfer, " fur tufts to warehouse. Remaining: ", stored_fur_tufts)
		
		# Resume passive production if we now have space
		if stored_fur_tufts < max_storage and not assigned_villager:
			start_passive_production()
		
		return true
	
	return false

# Job assignment functions
func create_rabbit_handler_job():
	if not has_rabbit_handler_job():
		var rabbit_job = Job.new(Job.JobType.RABBIT_HANDLER, self)
		JobManager.register_job(rabbit_job)
		print("Rabbit Hutch: Created rabbit handler job")

func has_rabbit_handler_job() -> bool:
	var rabbit_jobs = JobManager.get_jobs_by_type(Job.JobType.RABBIT_HANDLER)
	for job in rabbit_jobs:
		if job.workplace == self:
			return true
	return false

func remove_rabbit_handler_job():
	var rabbit_jobs = JobManager.get_jobs_by_type(Job.JobType.RABBIT_HANDLER)
	for job in rabbit_jobs:
		if job.workplace == self:
			JobManager.unregister_job(job)
			print("Rabbit Hutch: Removed rabbit handler job")
			break

# Updated job assignment functions
func assign_villager(villager):
	if assigned_villager:
		return false
	
	assigned_villager = villager
	stop_passive_production()  # Stop passive when worker assigned
	worker_production_timer.start()
	print("Rabbit Hutch: Assigned villager - switched to worker production")
	return true

func remove_villager():
	if not assigned_villager:
		return
	
	assigned_villager = null
	worker_production_timer.stop()
	
	# Resume passive production if we have internal storage space
	if stored_fur_tufts < max_storage:
		start_passive_production()
	
	print("Rabbit Hutch: Removed villager - switched back to passive production")

func has_assigned_villager() -> bool:
	return assigned_villager != null



func get_work_position() -> Vector3:
	return global_position + Vector3(2.0, 0, 1.0)  # East side

func get_actual_work_spot() -> Vector3:
	return global_position + Vector3(1, 0, 1)  # Center

# Status and info functions
func get_production_status() -> String:
	var status = "Fur Tufts: %d/%d" % [stored_fur_tufts, max_storage]
	
	if assigned_villager:
		var time_left = worker_production_timer.time_left
		status += " | Worker: %d sec" % int(time_left)
	elif stored_fur_tufts < max_storage:
		var time_left = passive_production_timer.time_left
		status += " | Passive: %d sec" % int(time_left)
	else:
		status += " | Production stopped (full)"
	
	return status

func can_be_clicked() -> bool:
	return stored_fur_tufts > 0

func on_building_selected():
	# This would be called when player clicks/selects the building
	if stored_fur_tufts > 0:
		collect_stored_tufts()

# Helper function
func find_warehouse():
	var warehouses = get_tree().get_nodes_in_group("warehouse")
	return warehouses[0] if warehouses.size() > 0 else null

# Identify as rabbit hutch
func is_rabbit_hutch() -> bool:
	return true

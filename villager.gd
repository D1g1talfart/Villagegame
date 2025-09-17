# villager.gd - Updated with hunger system and kitchen worker removed
extends CharacterBody3D
class_name Villager

signal job_completed
signal arrived_at_destination

enum State { IDLE, WALKING, WORKING }
enum WorkerState { 
	GOING_TO_SOURCE,     # Going to resource source (farm/heartwood/etc)
	GATHERING,           # Harvesting/gathering at source
	GOING_TO_STORAGE,    # Going to storage location
	DELIVERING,          # Delivering to storage
	# Builder states
	GOING_TO_WOOD_STORAGE,   # Going to wood storage to pick up wood
	GOING_TO_STONE_STORAGE,  # Going to stone storage to pick up stone
	PICKING_UP_RESOURCES,    # Picking up resources from storage
	GOING_TO_BUILD_SITE,     # Going to building being upgraded
	DELIVERING_TO_BUILD,     # Delivering resources to building
	# Hunger states
	GOING_TO_EAT,           # Going to kitchen to eat
	EATING                  # Eating at kitchen
}

@export var villager_name: String = "Villager"
@export var movement_speed: float = 3.0
@export var work_duration: float = 2.0
@export var hunger_interval: float = 60.0  # 3 minutes in seconds
@export var eating_duration: float = 2.0    # How long it takes to eat

var current_state: State = State.IDLE
var worker_state: WorkerState = WorkerState.GOING_TO_SOURCE
var previous_worker_state: WorkerState = WorkerState.GOING_TO_SOURCE  # To return after eating
var assigned_job: Job
var home_house: BuildableBuilding
var work_timer: float = 0.0
var hunger_timer: float
var needs_food: bool = false
var carrying_crops: int = 0
var carrying_wood: int = 0
var carrying_stone: int = 0
var carrying_fur_charm: int = 0  
var carrying_noble_trinket: int = 0 
var carrying_planks: int = 0
var pending_unassignment: bool = false
var walking_toward: String = ""

# Grid movement
var grid_movement: GridMovement

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready():
	add_to_group("villagers")
	setup_collision_layers()
	setup_appearance()
	setup_grid_movement()
	
	# Initialize hunger timer
	hunger_timer = hunger_interval
	
	call_deferred("connect_house_signals")

func setup_collision_layers():
	collision_layer = 4  # Layer 3
	collision_mask = 1   # Only ground layer
	print("Villager collision setup - Layer: ", collision_layer, " Mask: ", collision_mask)

func setup_grid_movement():
	grid_movement = GridMovement.new(self)
	grid_movement.movement_speed = movement_speed
	add_child(grid_movement)
	grid_movement.movement_finished.connect(_on_movement_finished)
	grid_movement.arrived_at_waypoint.connect(_on_waypoint_reached)
	print("Grid movement setup for ", villager_name)

func setup_appearance():
	if not mesh_instance.mesh:
		var capsule = CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.6
		mesh_instance.mesh = capsule
	mesh_instance.position = Vector3(0, 0.8, 0)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE
	mesh_instance.material_override = material

func connect_house_signals():
	if home_house:
		# Disconnect first to avoid duplicates
		if home_house.has_signal("building_moved") and home_house.building_moved.is_connected(_on_house_moved):
			home_house.building_moved.disconnect(_on_house_moved)
		
		# Reconnect
		if home_house.has_signal("building_moved"):
			home_house.building_moved.connect(_on_house_moved)
			print(villager_name, " connected to house movement signals")

func _physics_process(delta):
	# Update hunger timer (except for farm workers)
	if assigned_job and assigned_job.job_type != Job.JobType.FARM_WORKER:
		hunger_timer -= delta
		if hunger_timer <= 0 and not needs_food:
			needs_food = true
			print(villager_name, " is now hungry!")
	
	match current_state:
		State.IDLE:
			handle_idle_state()
		State.WALKING:
			# Grid movement handles the actual movement - don't interfere
			# Just keep villager on ground
			if abs(global_position.y - 0.1) > 0.01:
				global_position.y = 0.1
		State.WORKING:
			handle_working_state(delta)

func handle_idle_state():
	# PRIORITY 1: Handle hunger (except farm workers)
	if needs_food and assigned_job and assigned_job.job_type != Job.JobType.FARM_WORKER:
		var kitchen = get_kitchen()
		if kitchen and kitchen.has_method("can_eat") and kitchen.can_eat():
			if worker_state != WorkerState.GOING_TO_EAT and worker_state != WorkerState.EATING:
				print(villager_name, " needs food - going to kitchen")
				previous_worker_state = worker_state
				worker_state = WorkerState.GOING_TO_EAT
				walk_to_position(kitchen.get_work_position(), "kitchen_eating")
				return
		else:
			# No food available, wait or continue working
			print(villager_name, " is hungry but no food available")
			if not kitchen:
				# No kitchen - can't eat, continue working
				needs_food = false
				hunger_timer = hunger_interval
	
	# Handle eating states
	if worker_state == WorkerState.GOING_TO_EAT or worker_state == WorkerState.EATING:
		handle_eating_logic()
		return
	
	# PRIORITY 2: Handle pending unassignment
	if pending_unassignment and carrying_crops == 0 and carrying_wood == 0 and carrying_stone == 0:
		complete_pending_unassignment()
		go_to_house_idle()
		return
	
	if pending_unassignment and (carrying_crops > 0 or carrying_wood > 0 or carrying_stone > 0):
		# Handle pending deliveries for different resource types
		if carrying_crops > 0:
			var kitchen = get_kitchen()
			if kitchen and kitchen.has_method("can_accept_crops"):
				if not kitchen.can_accept_crops(carrying_crops):
					print(villager_name, " kitchen became full during pending unassignment - dropping crops")
					carrying_crops = 0
					reset_appearance()
					complete_pending_unassignment()
					go_to_house_idle()
					return
				else:
					worker_state = WorkerState.GOING_TO_STORAGE
					handle_resource_worker_cycle()
					return
		
		if carrying_wood > 0:
			var wood_storage = get_wood_storage()
			if wood_storage and wood_storage.has_method("can_accept_wood"):
				if not wood_storage.can_accept_wood(carrying_wood):
					print(villager_name, " wood storage became full during pending unassignment - dropping wood")
					carrying_wood = 0
					reset_appearance()
					complete_pending_unassignment()
					go_to_house_idle()
					return
				else:
					worker_state = WorkerState.GOING_TO_STORAGE
					handle_resource_worker_cycle()
					return
		
		if carrying_stone > 0:
			var stone_storage = get_stone_storage()
			if stone_storage and stone_storage.has_method("can_accept_stone"):
				if not stone_storage.can_accept_stone(carrying_stone):
					print(villager_name, " stone storage became full during pending unassignment - dropping stone")
					carrying_stone = 0
					reset_appearance()
					complete_pending_unassignment()
					go_to_house_idle()
					return
				else:
					worker_state = WorkerState.GOING_TO_STORAGE
					handle_resource_worker_cycle()
					return
	
	# PRIORITY 3: Handle work
	if assigned_job and assigned_job.should_work():
		if assigned_job.job_type == Job.JobType.FARM_WORKER or assigned_job.job_type == Job.JobType.WOOD_GATHERER or assigned_job.job_type == Job.JobType.STONE_GATHERER:
			# Check if we're carrying resources but storage is full
			if assigned_job.job_type == Job.JobType.FARM_WORKER and carrying_crops > 0 and worker_state == WorkerState.DELIVERING:
				var kitchen = get_kitchen()
				if kitchen and kitchen.has_method("can_accept_crops"):
					if kitchen.can_accept_crops(carrying_crops):
						deliver_crops_to_kitchen()
					else:
						return  # Wait for space
			elif assigned_job.job_type == Job.JobType.WOOD_GATHERER and carrying_wood > 0 and worker_state == WorkerState.DELIVERING:
				var wood_storage = get_wood_storage()
				if wood_storage and wood_storage.has_method("can_accept_wood"):
					if wood_storage.can_accept_wood(carrying_wood):
						deliver_wood_to_storage()
					else:
						return  # Wait for space
			elif assigned_job.job_type == Job.JobType.STONE_GATHERER and carrying_stone > 0 and worker_state == WorkerState.DELIVERING:
				var stone_storage = get_stone_storage()
				if stone_storage and stone_storage.has_method("can_accept_stone"):
					if stone_storage.can_accept_stone(carrying_stone):
						deliver_stone_to_storage()
					else:
						return  # Wait for space
			else:
				handle_resource_worker_cycle()
		elif assigned_job.job_type == Job.JobType.BUILDER:
			handle_builder_logic()
		elif assigned_job.job_type == Job.JobType.RABBIT_HANDLER:
			handle_rabbit_handler_logic()
		elif assigned_job.job_type == Job.JobType.ORNAMENT_CRAFTER: 
			handle_ornament_crafter_logic()   
		elif assigned_job.job_type == Job.JobType.PLANK_WORKER:  
			handle_plank_worker_logic()                   
		# REMOVED: KITCHEN_WORKER logic is no longer needed
	else:
		go_to_house_idle()

# NEW: Eating logic
func handle_eating_logic():
	var kitchen = get_kitchen()
	
	match worker_state:
		WorkerState.GOING_TO_EAT:
			if kitchen and kitchen.has_method("get_work_position"):
				var kitchen_entry = kitchen.get_work_position()
				if global_position.distance_to(kitchen_entry) > 1.5:
					# Still walking to kitchen
					return
		
		WorkerState.EATING:
			# Currently eating - handled in working state
			return

func handle_eating_arrival():
	var kitchen = get_kitchen()
	if kitchen and kitchen.has_method("get_work_position"):
		var kitchen_entry = kitchen.get_work_position()
		if global_position.distance_to(kitchen_entry) < 2.0:
			print("At kitchen for eating, teleporting to dining spot")
			var eating_spot = kitchen.get_actual_work_spot()
			global_position = eating_spot
			worker_state = WorkerState.EATING
			start_eating()

func start_eating():
	current_state = State.WORKING
	work_timer = eating_duration
	print(villager_name, " started eating")

func complete_eating():
	var kitchen = get_kitchen()
	if kitchen and kitchen.has_method("consume_meal"):
		if kitchen.consume_meal():
			print(villager_name, " finished eating!")
			needs_food = false
			hunger_timer = hunger_interval  # Reset hunger timer
			
			# Teleport back to kitchen exit
			var kitchen_exit = kitchen.get_work_position()
			global_position = kitchen_exit
			global_position.y = 0.1
			
			# Return to previous work state
			worker_state = previous_worker_state
			print(villager_name, " returning to work state: ", WorkerState.keys()[worker_state])
		else:
			print(villager_name, " tried to eat but no meals available!")
			# Stay hungry and try again later
			var kitchen_exit = kitchen.get_work_position()
			global_position = kitchen_exit
			global_position.y = 0.1
			worker_state = previous_worker_state

func handle_resource_worker_cycle():
	match assigned_job.job_type:
		Job.JobType.FARM_WORKER:
			handle_farm_worker_logic()
		Job.JobType.WOOD_GATHERER:
			handle_wood_gatherer_logic()
		Job.JobType.STONE_GATHERER:
			handle_stone_gatherer_logic()

func handle_farm_worker_logic():
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			if carrying_crops == 0:
				var farm = assigned_job.workplace
				if farm and farm.has_method("get_work_position"):
					var farm_entry = farm.get_work_position()
					if global_position.distance_to(farm_entry) > 1.5:
						print("Walking to farm entry point: ", farm_entry)
						walk_to_position(farm_entry, "farm")
			else:
				worker_state = WorkerState.GOING_TO_STORAGE
				handle_resource_worker_cycle()
		
		WorkerState.GOING_TO_STORAGE:
			if carrying_crops > 0:
				var kitchen = get_kitchen()
				if kitchen and kitchen.has_method("get_work_position"):
					if kitchen.has_method("can_accept_crops") and not kitchen.can_accept_crops(carrying_crops):
						print(villager_name, " waiting - kitchen full! ", kitchen.get_storage_status() if kitchen.has_method("get_storage_status") else "")
						return
					
					var kitchen_entry = kitchen.get_work_position()
					if global_position.distance_to(kitchen_entry) > 1.5:
						print("Walking to kitchen entry point: ", kitchen_entry)
						walk_to_position(kitchen_entry, "kitchen")
			else:
				worker_state = WorkerState.GOING_TO_SOURCE
				handle_resource_worker_cycle()

func handle_wood_gatherer_logic():
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			if carrying_wood == 0:
				var heartwood = assigned_job.workplace
				if heartwood and heartwood.has_method("get_work_position"):
					var heartwood_entry = heartwood.get_work_position()
					if global_position.distance_to(heartwood_entry) > 1.5:
						print("Walking to assigned heartwood entry point: ", heartwood_entry)
						walk_to_position(heartwood_entry, "heartwood")
			else:
				worker_state = WorkerState.GOING_TO_STORAGE
				handle_resource_worker_cycle()
		
		WorkerState.GOING_TO_STORAGE:
			if carrying_wood > 0:
				var wood_storage = get_wood_storage()
				if wood_storage and wood_storage.has_method("get_work_position"):
					if wood_storage.has_method("can_accept_wood") and not wood_storage.can_accept_wood(carrying_wood):
						print(villager_name, " waiting - wood storage full! ", wood_storage.get_storage_status() if wood_storage.has_method("get_storage_status") else "")
						return
					
					var storage_entry = wood_storage.get_work_position()
					if global_position.distance_to(storage_entry) > 1.5:
						print("Walking to wood storage entry point: ", storage_entry)
						walk_to_position(storage_entry, "wood_storage")
			else:
				worker_state = WorkerState.GOING_TO_SOURCE
				handle_resource_worker_cycle()

func handle_stone_gatherer_logic():
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			if carrying_stone == 0:
				var stone_quarry = assigned_job.workplace
				if stone_quarry and stone_quarry.has_method("get_work_position"):
					var quarry_entry = stone_quarry.get_work_position()
					if global_position.distance_to(quarry_entry) > 1.5:
						print("Walking to assigned stone quarry entry point: ", quarry_entry)
						walk_to_position(quarry_entry, "stone_quarry")
			else:
				worker_state = WorkerState.GOING_TO_STORAGE
				handle_stone_gatherer_logic()
		
		WorkerState.GOING_TO_STORAGE:
			if carrying_stone > 0:
				var stone_storage = get_stone_storage()
				if stone_storage and stone_storage.has_method("get_work_position"):
					if stone_storage.has_method("can_accept_stone") and not stone_storage.can_accept_stone(carrying_stone):
						print(villager_name, " waiting - stone storage full! ", stone_storage.get_storage_status() if stone_storage.has_method("get_storage_status") else "")
						return
					
					var storage_entry = stone_storage.get_work_position()
					if global_position.distance_to(storage_entry) > 1.5:
						print("Walking to stone storage entry point: ", storage_entry)
						walk_to_position(storage_entry, "stone_storage")
			else:
				worker_state = WorkerState.GOING_TO_SOURCE
				handle_stone_gatherer_logic()
				

func handle_rabbit_handler_logic():
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			var rabbit_hutch = assigned_job.workplace
			if rabbit_hutch and rabbit_hutch.has_method("get_work_position"):
				var hutch_entry = rabbit_hutch.get_work_position()
				if global_position.distance_to(hutch_entry) > 1.5:
					print("Walking to rabbit hutch entry point: ", hutch_entry)
					walk_to_position(hutch_entry, "rabbit_hutch")
				else:
					# We're at the hutch, start working
					worker_state = WorkerState.GATHERING
					start_working()
		
		WorkerState.GATHERING:
			# Stay at hutch and work - the hutch handles production automatically
			# Just need to periodically "work" to keep the system active
			if current_state == State.IDLE:
				start_working()

func handle_ornament_crafter_logic():
	var ornament_workshop = assigned_job.workplace
	
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			# Go to workshop initially
			if ornament_workshop and ornament_workshop.has_method("get_work_position"):
				var workshop_entry = ornament_workshop.get_work_position()
				if global_position.distance_to(workshop_entry) > 1.5:
					print("Walking to ornament workshop entry point: ", workshop_entry)
					walk_to_position(workshop_entry, "ornament_workshop")
		
		WorkerState.GATHERING:
			# At workshop - check if we need to collect resources or if we're waiting for craft
			if ornament_workshop.is_crafting:
				# Just wait at workshop while crafting
				if current_state == State.IDLE:
					start_working()  # Keep working animation while waiting
			else:
				# Check what resources we need to collect
				var needed = ornament_workshop.get_needed_resources()
				
				if needed["wood"] > 0 and carrying_wood == 0:
					# Need to get wood
					var wood_storage = get_wood_storage()
					if wood_storage and wood_storage.stored_wood > 0:
						worker_state = WorkerState.GOING_TO_WOOD_STORAGE
						walk_to_position(wood_storage.get_work_position(), "wood_storage")
						return
				
				if needed["stone"] > 0 and carrying_stone == 0:
					# Need to get stone
					var stone_storage = get_stone_storage()
					if stone_storage and stone_storage.stored_stone > 0:
						worker_state = WorkerState.GOING_TO_STONE_STORAGE
						walk_to_position(stone_storage.get_work_position(), "stone_storage")
						return
				
				# If we have resources to deliver
				if carrying_wood > 0 or carrying_stone > 0:
					worker_state = WorkerState.DELIVERING_TO_BUILD
					start_working()  # Deliver resources
				
				# Check if there's a finished item to collect
				if ornament_workshop.has_method("has_finished_item") and ornament_workshop.has_finished_item():
					worker_state = WorkerState.GOING_TO_STORAGE
					# Will be handled in the delivery logic
		
		WorkerState.GOING_TO_WOOD_STORAGE:
			# Handled in arrival logic
			pass
		
		WorkerState.GOING_TO_STONE_STORAGE:
			# Handled in arrival logic
			pass
		
		WorkerState.GOING_TO_STORAGE:
			# Going to warehouse with finished product
			var warehouse = get_warehouse()
			if warehouse and warehouse.has_method("get_work_position"):
				var warehouse_entry = warehouse.get_work_position()
				if global_position.distance_to(warehouse_entry) > 1.5:
					print("Walking to warehouse with finished ornament: ", warehouse_entry)
					walk_to_position(warehouse_entry, "warehouse")
		
		WorkerState.DELIVERING:
			# Delivering finished product to warehouse
			if current_state == State.IDLE:
				start_working()

func handle_plank_worker_logic():
	var plank_workshop = assigned_job.workplace
	
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			# Go to workshop initially
			if plank_workshop and plank_workshop.has_method("get_work_position"):
				var workshop_entry = plank_workshop.get_work_position()
				if global_position.distance_to(workshop_entry) > 1.5:
					print("Walking to plank workshop entry point: ", workshop_entry)
					walk_to_position(workshop_entry, "plank_workshop")
		
		WorkerState.GATHERING:
			# At workshop - check what we need to do
			if plank_workshop.is_crafting:
				# Wait at workshop while crafting
				if current_state == State.IDLE:
					start_working()  # Keep working animation while waiting
			elif plank_workshop.has_finished_planks():
				# Pick up finished planks and take to storage
				worker_state = WorkerState.GOING_TO_STORAGE
				start_working()  # Work animation to pick up planks
			else:
				# Check if we need wood
				var needed_wood = plank_workshop.get_needed_wood()
				if needed_wood > 0 and carrying_wood == 0:
					var wood_storage = get_wood_storage()
					if wood_storage and wood_storage.stored_wood > 0:
						worker_state = WorkerState.GOING_TO_WOOD_STORAGE
						walk_to_position(wood_storage.get_work_position(), "wood_storage")
						return
				
				# If we have wood to deliver
				if carrying_wood > 0:
					worker_state = WorkerState.DELIVERING_TO_BUILD
					start_working()  # Deliver wood
				
				# Otherwise just keep working/waiting
				if current_state == State.IDLE:
					start_working()
		
		WorkerState.GOING_TO_WOOD_STORAGE:
			# Handled in arrival logic
			pass
		
		WorkerState.GOING_TO_STORAGE:
			# Going to plank storage with finished planks
			if carrying_planks > 0:
				var plank_storage = get_plank_storage()
				if plank_storage and plank_storage.has_method("get_work_position"):
					# Check if storage can accept planks
					if not plank_storage.can_accept_planks(carrying_planks):
						print(villager_name, " waiting - plank storage full!")
						return
					
					var storage_entry = plank_storage.get_work_position()
					if global_position.distance_to(storage_entry) > 1.5:
						print("Walking to plank storage: ", storage_entry)
						walk_to_position(storage_entry, "plank_storage")
		
		WorkerState.DELIVERING:
			# Delivering planks to storage
			if current_state == State.IDLE:
				start_working()

func go_to_house_idle():
	if home_house:
		var house_pos: Vector3
		
		if home_house.has_method("get_entry_position"):
			house_pos = home_house.get_entry_position()
		else:
			house_pos = home_house.global_position + Vector3(1, 0, 0)
		
		var distance_to_house = global_position.distance_to(house_pos)
		
		if distance_to_house > 1:
			print("Walking to house entry at ", house_pos)
			walk_to_position(house_pos, "house")

func walk_to_position(pos: Vector3, destination_type: String = ""):
	print("=== WALK DEBUG ===")
	print(villager_name, " walking from ", global_position, " to ", pos)
	print("Walking toward: ", destination_type)
	
	walking_toward = destination_type
	current_state = State.WALKING
	
	if grid_movement.move_to_position(pos):
		print("Grid pathfinding successful")
	else:
		print("Grid pathfinding failed - staying idle")
		current_state = State.IDLE
		walking_toward = ""

func _on_movement_finished():
	print(villager_name, " reached destination! Was walking toward: ", walking_toward)
	current_state = State.IDLE
	arrived_at_destination.emit()
	global_position.y = 0.1
	check_arrival_action()

func _on_waypoint_reached(waypoint: Vector2i):
	# Optional: Could add sound effects or other feedback here
	pass

func check_arrival_action():
	# Handle eating arrival
	if walking_toward == "kitchen_eating":
		handle_eating_arrival()
		return
	
	if assigned_job:
		match assigned_job.job_type:
			Job.JobType.FARM_WORKER:
				handle_farm_worker_arrival()
			Job.JobType.WOOD_GATHERER:
				handle_wood_gatherer_arrival()
			Job.JobType.STONE_GATHERER:
				handle_stone_gatherer_arrival()
			Job.JobType.BUILDER:
				handle_builder_arrival()
			Job.JobType.RABBIT_HANDLER: 
				handle_rabbit_handler_arrival() 
			Job.JobType.ORNAMENT_CRAFTER: 
				handle_ornament_crafter_arrival() 
			Job.JobType.PLANK_WORKER: 
				handle_plank_worker_arrival()  

func handle_farm_worker_arrival():
	var farm = assigned_job.workplace
	var kitchen = get_kitchen()
	
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			if farm and farm.has_method("get_work_position"):
				var farm_entry = farm.get_work_position()
				if global_position.distance_to(farm_entry) < 2.0:
					print("At farm entry, teleporting to work spot")
					var work_spot = farm.get_actual_work_spot()
					global_position = work_spot
					worker_state = WorkerState.GATHERING
					start_working()
		
		WorkerState.GOING_TO_STORAGE:
			if kitchen and kitchen.has_method("get_work_position"):
				var kitchen_entry = kitchen.get_work_position()
				if global_position.distance_to(kitchen_entry) < 2.0:
					print("At kitchen entry, teleporting to work spot")
					var work_spot = kitchen.get_actual_work_spot()
					global_position = work_spot
					worker_state = WorkerState.DELIVERING
					deliver_crops_to_kitchen()

func handle_wood_gatherer_arrival():
	var heartwood = assigned_job.workplace
	var wood_storage = get_wood_storage()
	
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			if heartwood and heartwood.has_method("get_work_position"):
				var heartwood_entry = heartwood.get_work_position()
				if global_position.distance_to(heartwood_entry) < 2.0:
					print("At assigned heartwood entry, teleporting to work spot")
					var work_spot = heartwood.get_actual_work_spot()
					global_position = work_spot
					worker_state = WorkerState.GATHERING
					start_working()
		
		WorkerState.GOING_TO_STORAGE:
			if wood_storage and wood_storage.has_method("get_work_position"):
				var storage_entry = wood_storage.get_work_position()
				if global_position.distance_to(storage_entry) < 2.0:
					print("At wood storage entry, teleporting to work spot")
					var work_spot = wood_storage.get_actual_work_spot()
					global_position = work_spot
					worker_state = WorkerState.DELIVERING
					deliver_wood_to_storage()

func handle_stone_gatherer_arrival():
	var stone_quarry = assigned_job.workplace
	var stone_storage = get_stone_storage()
	
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			if stone_quarry and stone_quarry.has_method("get_work_position"):
				var quarry_entry = stone_quarry.get_work_position()
				if global_position.distance_to(quarry_entry) < 2.0:
					print("At assigned stone quarry entry, teleporting to work spot")
					var work_spot = stone_quarry.get_actual_work_spot()
					global_position = work_spot
					worker_state = WorkerState.GATHERING
					start_working()
		
		WorkerState.GOING_TO_STORAGE:
			if stone_storage and stone_storage.has_method("get_work_position"):
				var storage_entry = stone_storage.get_work_position()
				if global_position.distance_to(storage_entry) < 2.0:
					print("At stone storage entry, teleporting to work spot")
					var work_spot = stone_storage.get_actual_work_spot()
					global_position = work_spot
					worker_state = WorkerState.DELIVERING
					deliver_stone_to_storage()

func handle_rabbit_handler_arrival():
	var rabbit_hutch = assigned_job.workplace
	
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			if rabbit_hutch and rabbit_hutch.has_method("get_work_position"):
				var hutch_entry = rabbit_hutch.get_work_position()
				if global_position.distance_to(hutch_entry) < 2.0:
					print("At rabbit hutch entry, teleporting to work spot")
					var work_spot = rabbit_hutch.get_actual_work_spot()
					global_position = work_spot
					worker_state = WorkerState.GATHERING
					
					# Notify the hutch that we've arrived
					if rabbit_hutch.has_method("assign_villager"):
						rabbit_hutch.assign_villager(self)
					
					start_working()

func handle_ornament_crafter_arrival():
	var ornament_workshop = assigned_job.workplace
	
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			if ornament_workshop and ornament_workshop.has_method("get_work_position"):
				var workshop_entry = ornament_workshop.get_work_position()
				if global_position.distance_to(workshop_entry) < 2.0:
					print("At ornament workshop entry, teleporting to work spot")
					var work_spot = ornament_workshop.get_actual_work_spot()
					global_position = work_spot
					worker_state = WorkerState.GATHERING
					
					# Notify workshop we've arrived
					if ornament_workshop.has_method("assign_villager"):
						ornament_workshop.assign_villager(self)
					
					start_working()
		
		WorkerState.GOING_TO_WOOD_STORAGE:
			var wood_storage = get_wood_storage()
			if wood_storage and wood_storage.get_work_position().distance_to(global_position) < 2.0:
				print("At wood storage for crafting, picking up wood")
				global_position = wood_storage.get_actual_work_spot()
				worker_state = WorkerState.PICKING_UP_RESOURCES
				start_working()
		
		WorkerState.GOING_TO_STONE_STORAGE:
			var stone_storage = get_stone_storage()
			if stone_storage and stone_storage.get_work_position().distance_to(global_position) < 2.0:
				print("At stone storage for crafting, picking up stone")
				global_position = stone_storage.get_actual_work_spot()
				worker_state = WorkerState.PICKING_UP_RESOURCES
				start_working()
		
		WorkerState.GOING_TO_STORAGE:
			var warehouse = get_warehouse()
			if warehouse and warehouse.get_work_position().distance_to(global_position) < 2.0:
				print("At warehouse for ornament delivery")
				global_position = warehouse.get_actual_work_spot()
				worker_state = WorkerState.DELIVERING
				start_working()

func handle_plank_worker_arrival():
	var plank_workshop = assigned_job.workplace
	
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			if plank_workshop and plank_workshop.has_method("get_work_position"):
				var workshop_entry = plank_workshop.get_work_position()
				if global_position.distance_to(workshop_entry) < 2.0:
					print("At plank workshop entry, teleporting to work spot")
					var work_spot = plank_workshop.get_actual_work_spot()
					global_position = work_spot
					worker_state = WorkerState.GATHERING
					
					# Notify workshop we've arrived
					if plank_workshop.has_method("assign_villager"):
						plank_workshop.assign_villager(self)
					
					start_working()
		
		WorkerState.GOING_TO_WOOD_STORAGE:
			var wood_storage = get_wood_storage()
			if wood_storage and wood_storage.get_work_position().distance_to(global_position) < 2.0:
				print("At wood storage for plank crafting, picking up wood")
				global_position = wood_storage.get_actual_work_spot()
				worker_state = WorkerState.PICKING_UP_RESOURCES
				start_working()
		
		WorkerState.GOING_TO_STORAGE:
			var plank_storage = get_plank_storage()
			if plank_storage and plank_storage.get_work_position().distance_to(global_position) < 2.0:
				print("At plank storage for delivery")
				global_position = plank_storage.get_actual_work_spot()
				worker_state = WorkerState.DELIVERING
				start_working()

func handle_working_state(delta):
	work_timer -= delta
	if work_timer <= 0:
		complete_work()

func start_working():
	current_state = State.WORKING
	work_timer = work_duration
	print(villager_name, " started working")

func complete_work():
	print(villager_name, " work completed")
	current_state = State.IDLE
	
	# Handle eating completion
	if worker_state == WorkerState.EATING:
		complete_eating()
		return
	
	if assigned_job:
		perform_job_action()
	job_completed.emit()

func perform_job_action():
	match assigned_job.job_type:
		Job.JobType.FARM_WORKER:
			perform_farm_work()
		Job.JobType.WOOD_GATHERER:
			perform_wood_gathering()
		Job.JobType.STONE_GATHERER:
			perform_stone_gathering()
		Job.JobType.BUILDER:
			perform_builder_work()
		Job.JobType.RABBIT_HANDLER: 
			perform_rabbit_handler_work()  
		Job.JobType.ORNAMENT_CRAFTER:
			perform_ornament_crafter_work() 
		Job.JobType.PLANK_WORKER: 
			perform_plank_worker_work()  

func perform_farm_work():
	var farm = assigned_job.workplace
	if farm and farm.has_method("harvest_crop"):
		if farm.harvest_crop():
			carrying_crops = 1
			worker_state = WorkerState.GOING_TO_STORAGE
			
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.GREEN
			
			print(villager_name, " finished harvesting")
			
			# Teleport back to farm exit BEFORE pathfinding
			var farm_exit = farm.get_work_position()
			print("Teleporting from work spot to farm exit: ", farm_exit)
			global_position = farm_exit
			global_position.y = 0.1
			
			# Now pathfind to kitchen
			var kitchen = get_kitchen()
			if kitchen:
				walk_to_position(kitchen.get_work_position(), "kitchen")

func perform_wood_gathering():
	var heartwood = assigned_job.workplace
	if heartwood and heartwood.has_method("gather_wood"):
		if heartwood.gather_wood():
			carrying_wood = 1
			worker_state = WorkerState.GOING_TO_STORAGE
			
			# Change color to indicate carrying wood (brown)
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown for wood
			
			print(villager_name, " finished gathering wood from assigned heartwood")
			
			# Teleport back to heartwood exit
			var heartwood_exit = heartwood.get_work_position()
			print("Teleporting from work spot to heartwood exit: ", heartwood_exit)
			global_position = heartwood_exit
			global_position.y = 0.1
			
			# Now pathfind to wood storage
			var wood_storage = get_wood_storage()
			if wood_storage:
				walk_to_position(wood_storage.get_work_position(), "wood_storage")

func perform_stone_gathering():
	var stone_quarry = assigned_job.workplace
	if stone_quarry and stone_quarry.has_method("gather_stone"):
		if stone_quarry.gather_stone():
			carrying_stone = 1
			worker_state = WorkerState.GOING_TO_STORAGE
			
			# Change color to indicate carrying stone (gray)
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.GRAY
			
			print(villager_name, " finished gathering stone from assigned quarry")
			
			# Teleport back to quarry exit
			var quarry_exit = stone_quarry.get_work_position()
			print("Teleporting from work spot to stone quarry exit: ", quarry_exit)
			global_position = quarry_exit
			global_position.y = 0.1
			
			# Now pathfind to stone storage
			var stone_storage = get_stone_storage()
			if stone_storage:
				walk_to_position(stone_storage.get_work_position(), "stone_storage")

func perform_rabbit_handler_work():
	var rabbit_hutch = assigned_job.workplace
	if rabbit_hutch:
		print(villager_name, " is tending to the rabbits")
		# The hutch handles all the production logic automatically
		# We just need to stay here and keep working
		worker_state = WorkerState.GATHERING
		
		# Change color to indicate working with animals (light brown)
		var material = mesh_instance.material_override as StandardMaterial3D
		if material:
			material.albedo_color = Color(0.8, 0.6, 0.4)  # Light brown for rabbit work

func perform_ornament_crafter_work():
	var ornament_workshop = assigned_job.workplace
	
	match worker_state:
		WorkerState.PICKING_UP_RESOURCES:
			# Pick up resources for crafting
			var wood_storage = get_wood_storage()
			var stone_storage = get_stone_storage()
			
			# Check if we're at wood storage and need wood
			if wood_storage and global_position.distance_to(wood_storage.get_actual_work_spot()) < 1.0:
				var needed = ornament_workshop.get_needed_resources()
				if needed["wood"] > 0 and wood_storage.stored_wood > 0:
					var amount_to_take = min(needed["wood"], wood_storage.stored_wood)
					wood_storage.remove_wood(amount_to_take)
					carrying_wood = amount_to_take
					
					# Change color to indicate carrying wood
					var material = mesh_instance.material_override as StandardMaterial3D
					if material:
						material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown for wood
					print(villager_name, " picked up ", amount_to_take, " wood for crafting")
			
			# Check if we're at stone storage and need stone
			elif stone_storage and global_position.distance_to(stone_storage.get_actual_work_spot()) < 1.0:
				var needed = ornament_workshop.get_needed_resources()
				if needed["stone"] > 0 and stone_storage.stored_stone > 0:
					var amount_to_take = min(needed["stone"], stone_storage.stored_stone)
					stone_storage.remove_stone(amount_to_take)
					carrying_stone = amount_to_take
					
					# Change color to indicate carrying stone
					var material = mesh_instance.material_override as StandardMaterial3D
					if material:
						material.albedo_color = Color.GRAY
					print(villager_name, " picked up ", amount_to_take, " stone for crafting")
			
			# Return to workshop
			worker_state = WorkerState.GOING_TO_SOURCE
			var storage_exit = Vector3.ZERO
			if carrying_wood > 0:
				storage_exit = wood_storage.get_work_position()
			elif carrying_stone > 0:
				storage_exit = stone_storage.get_work_position()
			
			if storage_exit != Vector3.ZERO:
				global_position = storage_exit
				global_position.y = 0.1
			
			walk_to_position(ornament_workshop.get_work_position(), "ornament_workshop")
		
		WorkerState.DELIVERING_TO_BUILD:
			# Deliver resources to workshop
			if carrying_wood > 0:
				ornament_workshop.deliver_resource("wood", carrying_wood)
				carrying_wood = 0
				print(villager_name, " delivered wood for crafting")
			
			if carrying_stone > 0:
				ornament_workshop.deliver_resource("stone", carrying_stone)
				carrying_stone = 0
				print(villager_name, " delivered stone for crafting")
			
			# Reset appearance and continue working at workshop
			reset_appearance()
			worker_state = WorkerState.GATHERING
		
		WorkerState.GATHERING:
			# Just working/waiting at workshop
			print(villager_name, " is working at ornament workshop")
			
			# Change color to indicate crafting work (purple)
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color(0.7, 0.3, 0.7)  # Purple for crafting
		
		WorkerState.DELIVERING:
			# Deliver finished product to warehouse
			var warehouse = get_warehouse()
			if warehouse:
				var recipe = ornament_workshop.get_selected_recipe()
				var item_type = recipe["output_item"]
				
				if warehouse.add_trade_good(item_type, 1):
					print(villager_name, " delivered 1 ", item_type, " to warehouse")
					
					# Reset carrying flags
					carrying_fur_charm = 0
					carrying_noble_trinket = 0
					reset_appearance()
					
					# Return to workshop
					worker_state = WorkerState.GOING_TO_SOURCE
					var warehouse_exit = warehouse.get_work_position()
					global_position = warehouse_exit
					global_position.y = 0.1
					
					walk_to_position(ornament_workshop.get_work_position(), "ornament_workshop")

func perform_plank_worker_work():
	var plank_workshop = assigned_job.workplace
	
	match worker_state:
		WorkerState.PICKING_UP_RESOURCES:
			# Pick up wood from wood storage
			var wood_storage = get_wood_storage()
			if wood_storage and global_position.distance_to(wood_storage.get_actual_work_spot()) < 1.0:
				var needed_wood = plank_workshop.get_needed_wood()
				if needed_wood > 0 and wood_storage.stored_wood > 0:
					var amount_to_take = min(needed_wood, wood_storage.stored_wood)
					wood_storage.remove_wood(amount_to_take)
					carrying_wood = amount_to_take
					
					# Change color to indicate carrying wood
					var material = mesh_instance.material_override as StandardMaterial3D
					if material:
						material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown for wood
					print(villager_name, " picked up ", amount_to_take, " wood for plank crafting")
			
			# Return to workshop
			worker_state = WorkerState.GOING_TO_SOURCE
			var storage_exit = wood_storage.get_work_position()
			global_position = storage_exit
			global_position.y = 0.1
			
			walk_to_position(plank_workshop.get_work_position(), "plank_workshop")
		
		WorkerState.DELIVERING_TO_BUILD:
			# Deliver wood to workshop
			if carrying_wood > 0:
				plank_workshop.deliver_wood(carrying_wood)
				carrying_wood = 0
				print(villager_name, " delivered wood for plank crafting")
			
			# Reset appearance and continue working at workshop
			reset_appearance()
			worker_state = WorkerState.GATHERING
		
		WorkerState.GATHERING:
			# Pick up finished planks or just work/wait
			if plank_workshop.has_finished_planks():
				var planks_collected = plank_workshop.collect_finished_planks()
				if planks_collected > 0:
					carrying_planks = planks_collected
					
					# Change color to indicate carrying planks (light brown)
					var material = mesh_instance.material_override as StandardMaterial3D
					if material:
						material.albedo_color = Color(0.8, 0.6, 0.3)  # Light brown for planks
					
					print(villager_name, " collected ", planks_collected, " planks")
					worker_state = WorkerState.GOING_TO_STORAGE
					
					# Teleport to workshop exit
					var workshop_exit = plank_workshop.get_work_position()
					global_position = workshop_exit
					global_position.y = 0.1
					
					# Go to plank storage
					var plank_storage = get_plank_storage()
					if plank_storage:
						walk_to_position(plank_storage.get_work_position(), "plank_storage")
			else:
				# Just working at workshop
				print(villager_name, " is working at plank workshop")
				
				# Change color to indicate plank work (yellow-brown)
				var material = mesh_instance.material_override as StandardMaterial3D
				if material:
					material.albedo_color = Color(0.8, 0.7, 0.4)  # Yellow-brown for plank work
		
		WorkerState.DELIVERING:
			# Deliver planks to storage
			var plank_storage = get_plank_storage()
			if plank_storage and carrying_planks > 0:
				if plank_storage.add_planks(carrying_planks):
					print(villager_name, " delivered ", carrying_planks, " planks to storage")
					carrying_planks = 0
					reset_appearance()
					
					# Return to workshop
					worker_state = WorkerState.GOING_TO_SOURCE
					var storage_exit = plank_storage.get_work_position()
					global_position = storage_exit
					global_position.y = 0.1
					
					walk_to_position(plank_workshop.get_work_position(), "plank_workshop")
				else:
					print(villager_name, " cannot deliver planks - storage full!")
					# Wait at storage
					return

func deliver_crops_to_kitchen():
	var kitchen = get_kitchen()
	if kitchen and kitchen.has_method("add_crops") and carrying_crops > 0:
		# Double-check that kitchen can accept crops
		if kitchen.has_method("can_accept_crops") and not kitchen.can_accept_crops(carrying_crops):
			print(villager_name, " cannot deliver - kitchen became full! Waiting...")
			var kitchen_exit = kitchen.get_work_position()
			global_position = kitchen_exit
			global_position.y = 0.1
			return
		
		if kitchen.add_crops(carrying_crops):
			print(villager_name, " delivered ", carrying_crops, " crop(s) - auto-converting to meals")
			carrying_crops = 0
			reset_appearance()
			
			# Teleport back to kitchen exit
			var kitchen_exit = kitchen.get_work_position()
			print("Teleporting from kitchen work spot to kitchen exit: ", kitchen_exit)
			global_position = kitchen_exit
			global_position.y = 0.1
			
			if pending_unassignment:
				complete_pending_unassignment()
				if home_house:
					walk_to_position(home_house.get_entry_position(), "house")
				return
			
			worker_state = WorkerState.GOING_TO_SOURCE
			var farm = assigned_job.workplace
			if farm:
				walk_to_position(farm.get_work_position(), "farm")

func deliver_wood_to_storage():
	var wood_storage = get_wood_storage()
	if wood_storage and wood_storage.has_method("add_wood") and carrying_wood > 0:
		# Check if storage can accept wood
		if wood_storage.has_method("can_accept_wood") and not wood_storage.can_accept_wood(carrying_wood):
			print(villager_name, " cannot deliver - wood storage became full! Waiting...")
			var storage_exit = wood_storage.get_work_position()
			global_position = storage_exit
			global_position.y = 0.1
			return
		
		if wood_storage.add_wood(carrying_wood):
			print(villager_name, " delivered ", carrying_wood, " wood")
			carrying_wood = 0
			reset_appearance()
			
			# Teleport back to storage exit
			var storage_exit = wood_storage.get_work_position()
			print("Teleporting from storage work spot to storage exit: ", storage_exit)
			global_position = storage_exit
			global_position.y = 0.1
			
			if pending_unassignment:
				complete_pending_unassignment()
				if home_house:
					walk_to_position(home_house.get_entry_position(), "house")
				return
			
			worker_state = WorkerState.GOING_TO_SOURCE
			var heartwood = assigned_job.workplace
			if heartwood:
				walk_to_position(heartwood.get_work_position(), "heartwood")
		else:
			print(villager_name, " delivery failed - wood storage full! Waiting...")
			var storage_exit = wood_storage.get_work_position()
			global_position = storage_exit
			global_position.y = 0.1

func deliver_stone_to_storage():
	var stone_storage = get_stone_storage()
	if stone_storage and stone_storage.has_method("add_stone") and carrying_stone > 0:
		# Check if storage can accept stone
		if stone_storage.has_method("can_accept_stone") and not stone_storage.can_accept_stone(carrying_stone):
			print(villager_name, " cannot deliver - stone storage became full! Waiting...")
			var storage_exit = stone_storage.get_work_position()
			global_position = storage_exit
			global_position.y = 0.1
			return
		
		if stone_storage.add_stone(carrying_stone):
			print(villager_name, " delivered ", carrying_stone, " stone")
			carrying_stone = 0
			reset_appearance()
			
			# Teleport back to storage exit
			var storage_exit = stone_storage.get_work_position()
			print("Teleporting from storage work spot to storage exit: ", storage_exit)
			global_position = storage_exit
			global_position.y = 0.1
			
			if pending_unassignment:
				complete_pending_unassignment()
				if home_house:
					walk_to_position(home_house.get_entry_position(), "house")
				return
			
			worker_state = WorkerState.GOING_TO_SOURCE
			var stone_quarry = assigned_job.workplace
			if stone_quarry:
				walk_to_position(stone_quarry.get_work_position(), "stone_quarry")
		else:
			print(villager_name, " delivery failed - stone storage full! Waiting...")
			var storage_exit = stone_storage.get_work_position()
			global_position = storage_exit
			global_position.y = 0.1

# Builder functions (unchanged)
func handle_builder_logic():
	var building_being_upgraded = assigned_job.workplace
	
	if not building_being_upgraded or not building_being_upgraded.is_upgrading:
		print(villager_name, " - building upgrade completed or cancelled")
		return
	
	# Determine what resource we need to fetch
	var need_wood = building_being_upgraded.upgrade_resources_delivered.get("wood", 0) < building_being_upgraded.upgrade_resources_needed.get("wood", 0)
	var need_stone = building_being_upgraded.upgrade_resources_delivered.get("stone", 0) < building_being_upgraded.upgrade_resources_needed.get("stone", 0)
	
	match worker_state:
		WorkerState.GOING_TO_SOURCE:
			# Decide what resource to fetch first (prioritize wood)
			if need_wood and carrying_wood == 0 and carrying_stone == 0:
				var wood_storage = get_wood_storage()
				if wood_storage and wood_storage.stored_wood > 0:
					worker_state = WorkerState.GOING_TO_WOOD_STORAGE
					walk_to_position(wood_storage.get_work_position(), "wood_storage")
					return
			
			if need_stone and carrying_wood == 0 and carrying_stone == 0:
				var stone_storage = get_stone_storage()
				if stone_storage and stone_storage.stored_stone > 0:
					worker_state = WorkerState.GOING_TO_STONE_STORAGE
					walk_to_position(stone_storage.get_work_position(), "stone_storage")
					return
			
			# If we have resources, deliver them
			if carrying_wood > 0 or carrying_stone > 0:
				worker_state = WorkerState.GOING_TO_BUILD_SITE
				walk_to_position(building_being_upgraded.get_work_position(), "build_site")
		
		WorkerState.GOING_TO_WOOD_STORAGE:
			# This is handled in check_arrival_action
			pass
		
		WorkerState.GOING_TO_STONE_STORAGE:
			# This is handled in check_arrival_action
			pass
		
		WorkerState.GOING_TO_BUILD_SITE:
			# This is handled in check_arrival_action
			pass

func handle_builder_arrival():
	var building_being_upgraded = assigned_job.workplace
	
	match worker_state:
		WorkerState.GOING_TO_WOOD_STORAGE:
			var wood_storage = get_wood_storage()
			if wood_storage and wood_storage.get_work_position().distance_to(global_position) < 2.0:
				print("At wood storage, picking up wood")
				global_position = wood_storage.get_actual_work_spot()
				worker_state = WorkerState.PICKING_UP_RESOURCES
				start_working()  # Work animation for picking up
		
		WorkerState.GOING_TO_STONE_STORAGE:
			var stone_storage = get_stone_storage()
			if stone_storage and stone_storage.get_work_position().distance_to(global_position) < 2.0:
				print("At stone storage, picking up stone")
				global_position = stone_storage.get_actual_work_spot()
				worker_state = WorkerState.PICKING_UP_RESOURCES
				start_working()  # Work animation for picking up
		
		WorkerState.GOING_TO_BUILD_SITE:
			if building_being_upgraded and building_being_upgraded.get_work_position().distance_to(global_position) < 2.0:
				print("At build site, delivering resources")
				global_position = building_being_upgraded.get_actual_work_spot()
				worker_state = WorkerState.DELIVERING_TO_BUILD
				start_working()  # Work animation for delivering

func perform_builder_work():
	var building_being_upgraded = assigned_job.workplace
	
	match worker_state:
		WorkerState.PICKING_UP_RESOURCES:
			# Pick up resources from storage
			if carrying_wood == 0 and carrying_stone == 0:
				var wood_storage = get_wood_storage()
				var stone_storage = get_stone_storage()
				
				# Check if we're at wood storage and need wood
				if wood_storage and global_position.distance_to(wood_storage.get_actual_work_spot()) < 1.0:
					var need_wood = building_being_upgraded.upgrade_resources_delivered.get("wood", 0) < building_being_upgraded.upgrade_resources_needed.get("wood", 0)
					if need_wood and wood_storage.stored_wood > 0:
						wood_storage.remove_wood(1)
						carrying_wood = 1
						# Change color to indicate carrying wood
						var material = mesh_instance.material_override as StandardMaterial3D
						if material:
							material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown for wood
						print(villager_name, " picked up 1 wood")
				
				# Check if we're at stone storage and need stone
				elif stone_storage and global_position.distance_to(stone_storage.get_actual_work_spot()) < 1.0:
					var need_stone = building_being_upgraded.upgrade_resources_delivered.get("stone", 0) < building_being_upgraded.upgrade_resources_needed.get("stone", 0)
					if need_stone and stone_storage.stored_stone > 0:
						stone_storage.remove_stone(1)
						carrying_stone = 1
						# Change color to indicate carrying stone
						var material = mesh_instance.material_override as StandardMaterial3D
						if material:
							material.albedo_color = Color.GRAY
						print(villager_name, " picked up 1 stone")
			
			# Go to build site
			worker_state = WorkerState.GOING_TO_BUILD_SITE
			var storage_exit = Vector3.ZERO
			if carrying_wood > 0:
				storage_exit = get_wood_storage().get_work_position()
			elif carrying_stone > 0:
				storage_exit = get_stone_storage().get_work_position()
			
			if storage_exit != Vector3.ZERO:
				global_position = storage_exit
				global_position.y = 0.1
			
			walk_to_position(building_being_upgraded.get_work_position(), "build_site")
		
		WorkerState.DELIVERING_TO_BUILD:
			# Deliver resources to building
			if carrying_wood > 0:
				building_being_upgraded.deliver_upgrade_resource("wood", 1)
				carrying_wood = 0
				print(villager_name, " delivered 1 wood to upgrade")
			elif carrying_stone > 0:
				building_being_upgraded.deliver_upgrade_resource("stone", 1)
				carrying_stone = 0
				print(villager_name, " delivered 1 stone to upgrade")
			
			# Reset appearance
			reset_appearance()
			
			# Go back to get more resources or finish
			worker_state = WorkerState.GOING_TO_SOURCE
			
			# Teleport back to build site exit
			var build_exit = building_being_upgraded.get_work_position()
			global_position = build_exit
			global_position.y = 0.1

func reset_appearance():
	var material = mesh_instance.material_override as StandardMaterial3D
	if material:
		material.albedo_color = Color.ORANGE

func get_kitchen() -> Node3D:
	var village = get_parent()
	for child in village.get_children():
		if child.has_method("is_kitchen"):
			return child
	return null

func get_wood_storage() -> Node3D:
	var village = get_parent()
	for child in village.get_children():
		if child.has_method("is_wood_storage"):
			return child
	return null

func get_stone_storage() -> Node3D:
	var village = get_parent()
	for child in village.get_children():
		if child.has_method("is_stone_storage"):
			return child
	return null

func get_warehouse() -> Node3D:
	var village = get_parent()
	for child in village.get_children():
		if child.has_method("is_warehouse"):
			return child
	return null

func get_plank_storage() -> Node3D:
	var village = get_parent()
	for child in village.get_children():
		if child.has_method("is_plank_storage"):
			return child
	return null

# Job assignment functions
func assign_job(job: Job):
	if assigned_job and assigned_job != job:
		unassign_job()
	
	if job.assigned_villager and job.assigned_villager != self:
		job.assigned_villager.unassign_job()
	
	assigned_job = job
	if job:
		job.assign_villager(self)
		print(villager_name, " assigned to job: ", job.job_type)
		
		# Reset state and resources based on job type
		match job.job_type:
			Job.JobType.FARM_WORKER:
				worker_state = WorkerState.GOING_TO_SOURCE
				carrying_crops = 0
				carrying_wood = 0
				carrying_stone = 0
			Job.JobType.WOOD_GATHERER:
				worker_state = WorkerState.GOING_TO_SOURCE
				carrying_crops = 0
				carrying_wood = 0
				carrying_stone = 0
			Job.JobType.STONE_GATHERER:
				worker_state = WorkerState.GOING_TO_SOURCE
				carrying_crops = 0
				carrying_wood = 0
				carrying_stone = 0
			Job.JobType.BUILDER:
				worker_state = WorkerState.GOING_TO_SOURCE
				carrying_crops = 0
				carrying_wood = 0
				carrying_stone = 0
			Job.JobType.RABBIT_HANDLER: 
				worker_state = WorkerState.GOING_TO_SOURCE
				carrying_crops = 0
				carrying_wood = 0
				carrying_stone = 0
			Job.JobType.ORNAMENT_CRAFTER:  
				worker_state = WorkerState.GOING_TO_SOURCE
				carrying_crops = 0
				carrying_wood = 0
				carrying_stone = 0
				carrying_fur_charm = 0
				carrying_noble_trinket = 0
			Job.JobType.PLANK_WORKER:  # ADD THIS CASE
				worker_state = WorkerState.GOING_TO_SOURCE
				carrying_crops = 0
				carrying_wood = 0
				carrying_stone = 0
				carrying_planks = 0
		
		# Reset visual appearance
		reset_appearance()

func unassign_job():
	if assigned_job:
		# Special handling for rabbit handler - notify hutch
		if assigned_job.job_type == Job.JobType.RABBIT_HANDLER:
			var rabbit_hutch = assigned_job.workplace
			if rabbit_hutch and rabbit_hutch.has_method("remove_villager"):
				rabbit_hutch.remove_villager()
		
		# Special handling for ornament crafter - notify workshop  # ADD THIS BLOCK
		elif assigned_job.job_type == Job.JobType.ORNAMENT_CRAFTER:
			var ornament_workshop = assigned_job.workplace
			if ornament_workshop and ornament_workshop.has_method("remove_villager"):
				ornament_workshop.remove_villager()
		
		# Special handling for plank worker - notify workshop  # ADD THIS BLOCK
		elif assigned_job.job_type == Job.JobType.PLANK_WORKER:
			var plank_workshop = assigned_job.workplace
			if plank_workshop and plank_workshop.has_method("remove_villager"):
				plank_workshop.remove_villager()
		
		var has_resources = carrying_crops > 0 or carrying_wood > 0 or carrying_stone > 0 or carrying_planks > 0
		
		if has_resources:
			# Check if we can deliver resources
			var can_deliver = false
			
			if carrying_crops > 0:
				var kitchen = get_kitchen()
				if kitchen and kitchen.has_method("can_accept_crops") and kitchen.can_accept_crops(carrying_crops):
					can_deliver = true
			
			if carrying_wood > 0:
				var wood_storage = get_wood_storage()
				if wood_storage and wood_storage.has_method("can_accept_wood") and wood_storage.can_accept_wood(carrying_wood):
					can_deliver = true
			
			if carrying_stone > 0:
				var stone_storage = get_stone_storage()
				if stone_storage and stone_storage.has_method("can_accept_stone") and stone_storage.can_accept_stone(carrying_stone):
					can_deliver = true
			
			if can_deliver:
				print("Will finish delivery before going home")
				pending_unassignment = true
				return
			else:
				# Drop resources and go home immediately
				print(villager_name, " unassigned with resources but storage full - dropping resources")
				carrying_crops = 0
				carrying_wood = 0
				carrying_stone = 0
				reset_appearance()
		
		# Clear job assignment
		assigned_job.unassign_villager()
		assigned_job = null
		pending_unassignment = false
		
		worker_state = WorkerState.GOING_TO_SOURCE
		carrying_crops = 0
		carrying_wood = 0
		carrying_stone = 0
		
		if current_state == State.WALKING:
			grid_movement.stop_movement()
		
		go_to_house_idle()

func complete_pending_unassignment():
	if pending_unassignment:
		if assigned_job:
			assigned_job.unassign_villager()
		assigned_job = null
		
		worker_state = WorkerState.GOING_TO_SOURCE
		carrying_crops = 0
		carrying_wood = 0
		carrying_stone = 0
		carrying_planks = 0
		pending_unassignment = false
		reset_appearance()

func _on_house_moved(building: BuildableBuilding, new_position: Vector2i):
	print("=== HOUSE MOVED ===")
	print(villager_name, "'s house moved to: ", new_position)
	print("Currently walking toward: ", walking_toward)
	print("Current state: ", State.keys()[current_state])
	
	# If we're walking to the house OR if we're idle and should go home, redirect immediately
	if (current_state == State.WALKING and walking_toward == "house") or (current_state == State.IDLE and not assigned_job):
		print("Immediately redirecting to new house location")
		var new_house_target = building.get_entry_position()
		
		if grid_movement.redirect_to_position(new_house_target):
			walking_toward = "house"
			current_state = State.WALKING
		else:
			print("Failed to redirect to new house position")
	else:
		print("House moved but villager not affected")

func _on_workplace_moved(building: BuildableBuilding, new_position: Vector2i):
	print("=== WORKPLACE MOVED ===")
	print(villager_name, "'s workplace moved to: ", new_position)
	print("Currently walking toward: ", walking_toward)
	
	if current_state == State.WALKING and (walking_toward == "farm" or walking_toward == "kitchen" or walking_toward == "heartwood" or walking_toward == "wood_storage"):
		var new_target = Vector3.ZERO
		
		if walking_toward == "farm" and building == assigned_job.workplace:
			new_target = assigned_job.workplace.get_work_position()
		elif walking_toward == "heartwood" and building == assigned_job.workplace:
			new_target = assigned_job.workplace.get_work_position()
		elif walking_toward == "kitchen" and building.has_method("is_kitchen"):
			new_target = building.get_work_position()
		elif walking_toward == "wood_storage" and building.has_method("is_wood_storage"):
			new_target = building.get_work_position()
		
		if new_target != Vector3.ZERO:
			print("Immediately redirecting to new workplace location")
			if grid_movement.redirect_to_position(new_target):
				pass
			else:
				print("Failed to redirect to new workplace position")
		else:
			print("Workplace moved but couldn't determine new target")
	else:
		print("Workplace moved but villager not affected")

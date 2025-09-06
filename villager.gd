# villager.gd - Updated for grid-based movement
extends CharacterBody3D
class_name Villager

signal job_completed
signal arrived_at_destination

enum State { IDLE, WALKING, WORKING }
enum FarmWorkerState { GOING_TO_FARM, HARVESTING, GOING_TO_KITCHEN, DELIVERING }

@export var villager_name: String = "Villager"
@export var movement_speed: float = 3.0
@export var work_duration: float = 2.0

var current_state: State = State.IDLE
var farm_worker_state: FarmWorkerState = FarmWorkerState.GOING_TO_FARM
var assigned_job: Job
var home_house: BuildableBuilding
var work_timer: float = 0.0
var carrying_crops: int = 0
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
	if pending_unassignment and carrying_crops == 0:
		complete_pending_unassignment()
		go_to_house_idle()
		return
	
	if pending_unassignment and carrying_crops > 0:
		print("Pending unassignment - finishing crop delivery")
		farm_worker_state = FarmWorkerState.GOING_TO_KITCHEN
		handle_farm_worker_cycle()
		return
	
	if assigned_job and assigned_job.should_work():
		if assigned_job.job_type == Job.JobType.FARM_WORKER:
			handle_farm_worker_cycle()
		elif assigned_job.job_type == Job.JobType.KITCHEN_WORKER:
			handle_kitchen_worker_cycle()
	else:
		go_to_house_idle()

func handle_farm_worker_cycle():
	match farm_worker_state:
		FarmWorkerState.GOING_TO_FARM:
			if carrying_crops == 0:
				var farm = assigned_job.workplace
				if farm and farm.has_method("get_work_position"):
					var farm_entry = farm.get_work_position()
					if global_position.distance_to(farm_entry) > 1.5:
						print("Walking to farm entry point: ", farm_entry)
						walk_to_position(farm_entry, "farm")
			else:
				farm_worker_state = FarmWorkerState.GOING_TO_KITCHEN
				handle_farm_worker_cycle()
		
		FarmWorkerState.GOING_TO_KITCHEN:
			if carrying_crops > 0:
				var kitchen = get_kitchen()
				if kitchen and kitchen.has_method("get_work_position"):
					var kitchen_entry = kitchen.get_work_position()
					if global_position.distance_to(kitchen_entry) > 1.5:
						print("Walking to kitchen entry point: ", kitchen_entry)
						walk_to_position(kitchen_entry, "kitchen")
			else:
				farm_worker_state = FarmWorkerState.GOING_TO_FARM
				handle_farm_worker_cycle()

func handle_kitchen_worker_cycle():
	var kitchen = get_kitchen()
	if kitchen:
		var kitchen_pos = kitchen.get_work_position()
		if global_position.distance_to(kitchen_pos) > 1.5:
			walk_to_position(kitchen_pos, "kitchen")
		elif kitchen.can_convert_crops():
			start_working()
	else:
		go_to_house_idle()

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
	if assigned_job:
		match assigned_job.job_type:
			Job.JobType.FARM_WORKER:
				handle_farm_worker_arrival()
			Job.JobType.KITCHEN_WORKER:
				handle_kitchen_worker_arrival()

func handle_farm_worker_arrival():
	var farm = assigned_job.workplace
	var kitchen = get_kitchen()
	
	match farm_worker_state:
		FarmWorkerState.GOING_TO_FARM:
			if farm and farm.has_method("get_work_position"):
				var farm_entry = farm.get_work_position()
				if global_position.distance_to(farm_entry) < 2.0:
					print("At farm entry, teleporting to work spot")
					var work_spot = farm.get_actual_work_spot()
					global_position = work_spot
					farm_worker_state = FarmWorkerState.HARVESTING
					start_working()
		
		FarmWorkerState.GOING_TO_KITCHEN:
			if kitchen and kitchen.has_method("get_work_position"):
				var kitchen_entry = kitchen.get_work_position()
				if global_position.distance_to(kitchen_entry) < 2.0:
					print("At kitchen entry, teleporting to work spot")
					var work_spot = kitchen.get_actual_work_spot()
					global_position = work_spot
					farm_worker_state = FarmWorkerState.DELIVERING
					deliver_crops_to_kitchen()

func handle_kitchen_worker_arrival():
	var kitchen = get_kitchen()
	if kitchen and global_position.distance_to(kitchen.global_position) < 2.0:
		if kitchen.has_method("get_actual_work_spot"):
			global_position = kitchen.get_actual_work_spot()
			print("Kitchen worker teleported to work spot")
		
		if kitchen.can_convert_crops():
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
	if assigned_job:
		perform_job_action()
	job_completed.emit()

func perform_job_action():
	if assigned_job.job_type == Job.JobType.FARM_WORKER:
		perform_farm_work()
	elif assigned_job.job_type == Job.JobType.KITCHEN_WORKER:
		perform_kitchen_work()

func perform_farm_work():
	var farm = assigned_job.workplace
	if farm and farm.has_method("harvest_crop"):
		if farm.harvest_crop():
			carrying_crops = 1
			farm_worker_state = FarmWorkerState.GOING_TO_KITCHEN
			
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.GREEN
			
			print(villager_name, " finished harvesting")
			
			# IMPORTANT: Teleport back to farm exit BEFORE pathfinding
			var farm_exit = farm.get_work_position()
			print("Teleporting from work spot to farm exit: ", farm_exit)
			global_position = farm_exit
			global_position.y = 0.1
			
			# Now pathfind to kitchen
			var kitchen = get_kitchen()
			if kitchen:
				walk_to_position(kitchen.get_work_position(), "kitchen")

func perform_kitchen_work():
	var kitchen = get_kitchen()
	if kitchen and kitchen.has_method("convert_crops_to_meals"):
		if kitchen.convert_crops_to_meals():
			print(villager_name, " converted crops to meals")
			
			# Teleport back to kitchen exit after working
			var kitchen_exit = kitchen.get_work_position()
			print("Kitchen worker teleporting back to exit: ", kitchen_exit)
			global_position = kitchen_exit
			global_position.y = 0.1

func deliver_crops_to_kitchen():
	var kitchen = get_kitchen()
	if kitchen and kitchen.has_method("add_crops") and carrying_crops > 0:
		if kitchen.add_crops(carrying_crops):
			print(villager_name, " delivered ", carrying_crops, " crop(s)")
			carrying_crops = 0
			
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.ORANGE
			
			# IMPORTANT: Teleport back to kitchen exit BEFORE pathfinding
			var kitchen_exit = kitchen.get_work_position()
			print("Teleporting from kitchen work spot to kitchen exit: ", kitchen_exit)
			global_position = kitchen_exit
			global_position.y = 0.1
			
			if pending_unassignment:
				complete_pending_unassignment()
				if home_house:
					walk_to_position(home_house.get_entry_position(), "house")
				return
			
			farm_worker_state = FarmWorkerState.GOING_TO_FARM
			var farm = assigned_job.workplace
			if farm:
				walk_to_position(farm.get_work_position(), "farm")

func get_kitchen() -> Node3D:
	var village = get_parent()
	for child in village.get_children():
		if child.has_method("is_kitchen"):
			return child
	return null

# Job assignment functions remain the same...
func assign_job(job: Job):
	if assigned_job and assigned_job != job:
		unassign_job()
	
	if job.assigned_villager and job.assigned_villager != self:
		job.assigned_villager.unassign_job()
	
	assigned_job = job
	if job:
		job.assign_villager(self)
		print(villager_name, " assigned to job: ", job.job_type)
		
		if job.job_type == Job.JobType.FARM_WORKER:
			farm_worker_state = FarmWorkerState.GOING_TO_FARM
			carrying_crops = 0
			
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.ORANGE

func unassign_job():
	if assigned_job:
		if carrying_crops > 0:
			print("Will finish delivery before going home")
			pending_unassignment = true
			return
		else:
			assigned_job.unassign_villager()
			assigned_job = null
			
			farm_worker_state = FarmWorkerState.GOING_TO_FARM
			carrying_crops = 0
			pending_unassignment = false
			
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.ORANGE
			
			if current_state == State.WALKING:
				grid_movement.stop_movement()
				go_to_house_idle()

func complete_pending_unassignment():
	if pending_unassignment:
		if assigned_job:
			assigned_job.unassign_villager()
		assigned_job = null
		
		farm_worker_state = FarmWorkerState.GOING_TO_FARM
		carrying_crops = 0
		pending_unassignment = false
		
		var material = mesh_instance.material_override as StandardMaterial3D
		if material:
			material.albedo_color = Color.ORANGE

func _on_house_moved(building: BuildableBuilding, new_position: Vector2i):
	print("=== HOUSE MOVED ===")
	print(villager_name, "'s house moved to: ", new_position)
	print("Currently walking toward: ", walking_toward)
	print("Current state: ", State.keys()[current_state])
	
	# If we're walking to the house OR if we're idle and should go home, redirect immediately
	if (current_state == State.WALKING and walking_toward == "house") or (current_state == State.IDLE and not assigned_job):
		print("Immediately redirecting to new house location")
		var new_house_target = building.get_entry_position()
		
		# Use the new redirect function for immediate response
		if grid_movement.redirect_to_position(new_house_target):
			walking_toward = "house"
			current_state = State.WALKING
		else:
			print("Failed to redirect to new house position")
	else:
		print("House moved but villager not affected (state: ", State.keys()[current_state], ", walking toward: ", walking_toward, ")")

func _on_workplace_moved(building: BuildableBuilding, new_position: Vector2i):
	print("=== WORKPLACE MOVED ===")
	print(villager_name, "'s workplace moved to: ", new_position)
	print("Currently walking toward: ", walking_toward)
	
	# Only update navigation if we were walking to the workplace
	if current_state == State.WALKING and (walking_toward == "farm" or walking_toward == "kitchen"):
		var new_target = Vector3.ZERO
		
		if walking_toward == "farm" and building == assigned_job.workplace:
			new_target = assigned_job.workplace.get_work_position()
		elif walking_toward == "kitchen" and building.has_method("is_kitchen"):
			new_target = building.get_work_position()
		
		if new_target != Vector3.ZERO:
			print("Immediately redirecting to new workplace location")
			if grid_movement.redirect_to_position(new_target):
				# walking_toward stays the same
				pass
			else:
				print("Failed to redirect to new workplace position")
		else:
			print("Workplace moved but couldn't determine new target")
	else:
		print("Workplace moved but villager not affected")

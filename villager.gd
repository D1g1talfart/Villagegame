# Complete Villager.gd with improved workflow
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
var target_position: Vector3
var work_timer: float = 0.0
var carrying_crops: int = 0
var debug_timer: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
	setup_appearance()
	# Connect the navigation signal
	if navigation_agent:
		navigation_agent.target_reached.connect(_on_target_reached)
	
	# Small delay to let NavigationServer set up
	call_deferred("setup_navigation")
	
	# Connect to house signals (workplace signals are connected when job is assigned)
	call_deferred("connect_house_signals")

# Add this helper function
func connect_house_signals():
	if home_house and home_house.has_signal("building_moved"):
		home_house.building_moved.connect(_on_house_moved)
		print(villager_name, " connected to house movement signals in _ready")
	
func _exit_tree():
	disconnect_from_workplace_signals()

func setup_navigation():
	if navigation_agent:
		navigation_agent.target_position = global_position
		print("Navigation setup for ", villager_name)
	else:
		print("ERROR: No NavigationAgent3D found for ", villager_name)

func setup_appearance():
	# Simple villager appearance
	if not mesh_instance.mesh:
		var capsule = CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.6
		mesh_instance.mesh = capsule
	mesh_instance.position = Vector3(0, 0.8, 0)
	
	# Give villager a color
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE
	mesh_instance.material_override = material

func _physics_process(delta):
	match current_state:
		State.IDLE:
			handle_idle_state()
		State.WALKING:
			handle_walking_state(delta)
		State.WORKING:
			handle_working_state(delta)
	
	# Keep villager on the ground
	if global_position.y != 0.1:
		global_position.y = 0.1

func print_debug_info():
	print("=== ", villager_name, " DEBUG ===")
	print("State: ", State.keys()[current_state])
	print("Position: ", global_position)
	print("Carrying crops: ", carrying_crops)
	if assigned_job:
		print("Job: ", assigned_job.job_type)
		if assigned_job.job_type == Job.JobType.FARM_WORKER:
			print("Farm state: ", FarmWorkerState.keys()[farm_worker_state])

func handle_idle_state():
	if assigned_job and assigned_job.should_work():
		if assigned_job.job_type == Job.JobType.FARM_WORKER:
			print("Handling farm worker cycle - State: ", FarmWorkerState.keys()[farm_worker_state])
			handle_farm_worker_cycle()
		elif assigned_job.job_type == Job.JobType.KITCHEN_WORKER:
			handle_kitchen_worker_cycle()
	else:
		# No job - go home and idle
		go_to_house_idle()

func handle_farm_worker_cycle():
	match farm_worker_state:
		FarmWorkerState.GOING_TO_FARM:
			if carrying_crops == 0:
				var farm_pos = assigned_job.get_work_position()
				if global_position.distance_to(farm_pos) > 1.5:
					walk_to_position(farm_pos)
			else:
				farm_worker_state = FarmWorkerState.GOING_TO_KITCHEN
				handle_farm_worker_cycle()
		
		FarmWorkerState.HARVESTING:
			# Currently harvesting - should be in WORKING state, not IDLE
			# This shouldn't happen, but if it does, just wait
			print("WARNING: In HARVESTING state but also IDLE - waiting for work to complete")
		
		FarmWorkerState.DELIVERING:
			# Currently delivering - shouldn't be here either
			print("WARNING: In DELIVERING state but also IDLE")
		
		FarmWorkerState.GOING_TO_KITCHEN:
			if carrying_crops > 0:
				var kitchen = get_kitchen()
				if kitchen:
					var kitchen_pos = kitchen.global_position
					if global_position.distance_to(kitchen_pos) > 1.5:
						walk_to_position(kitchen_pos)
				else:
					print("ERROR: No kitchen found!")
					go_to_house_idle()
			else:
				# Not carrying crops, go back to farm
				farm_worker_state = FarmWorkerState.GOING_TO_FARM
				handle_farm_worker_cycle()

func handle_kitchen_worker_cycle():
	# Kitchen worker stays at kitchen and converts crops
	var kitchen = get_kitchen()
	if kitchen:
		var kitchen_pos = kitchen.global_position
		if global_position.distance_to(kitchen_pos) > 1.5:
			walk_to_position(kitchen_pos)
		elif kitchen.can_convert_crops():
			start_working()
	else:
		go_to_house_idle()

func go_to_house_idle():
	if home_house:
		var house_pos = home_house.global_position + Vector3(1, 0, 0)
		var distance_to_house = global_position.distance_to(house_pos)
		
		# Only walk if far from house OR if currently walking to wrong target
		if distance_to_house > 1 or (current_state == State.WALKING and target_position.distance_to(house_pos) > 1.0):
			print("=== WALK DEBUG ===")
			print(villager_name, " trying to walk to ", house_pos)
			print("Current position: ", global_position)
			print("Distance: ", distance_to_house)
			walk_to_position(house_pos)

func handle_walking_state(delta):
	if not navigation_agent.is_navigation_finished():
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = (next_path_position - global_position).normalized()
		
		velocity = direction * movement_speed
		move_and_slide()
		
		# Face movement direction - ONLY rotate around Y-axis (no tipping)
		if velocity.length() > 0.1:
			var flat_direction = Vector3(direction.x, 0, direction.z).normalized()
			if flat_direction.length() > 0.1:
				var target_rotation = atan2(flat_direction.x, flat_direction.z)
				rotation.y = target_rotation

func handle_working_state(delta):
	work_timer -= delta
	print("Working... timer: ", work_timer, " (", villager_name, ")")
	if work_timer <= 0:
		print("Work timer finished! Calling complete_work()")
		complete_work()

func walk_to_position(pos: Vector3):
	target_position = pos
	navigation_agent.target_position = pos
	current_state = State.WALKING
	print("=== WALK DEBUG ===")
	print(villager_name, " trying to walk to ", pos)
	print("Current position: ", global_position)
	print("Distance: ", global_position.distance_to(pos))
	print("Navigation target set to: ", navigation_agent.target_position)
	
	# Check if navigation agent is working
	await get_tree().process_frame  # Wait one frame
	print("Navigation path exists: ", not navigation_agent.is_navigation_finished())

func _on_target_reached():
	print(villager_name, " reached target!")
	current_state = State.IDLE
	arrived_at_destination.emit()
	
	# Force position to be on ground
	global_position.y = 0.1
	
	check_arrival_action()

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
			# Arrived near farm - teleport to work spot and start working
			if farm and global_position.distance_to(assigned_job.get_work_position()) < 2.0:
				if farm.can_harvest():
					# TELEPORT to actual work spot
					if farm.has_method("get_actual_work_spot"):
						global_position = farm.get_actual_work_spot()
						print("Teleported to farm work spot: ", global_position)
					
					farm_worker_state = FarmWorkerState.HARVESTING
					start_working()
				else:
					print("Farm not ready for harvest, waiting...")
		
		FarmWorkerState.GOING_TO_KITCHEN:
			# Arrived near kitchen - teleport to work spot and deliver
			if kitchen and global_position.distance_to(kitchen.get_work_position()) < 2.0:
				# TELEPORT to actual kitchen work spot
				if kitchen.has_method("get_actual_work_spot"):
					global_position = kitchen.get_actual_work_spot()
					print("Teleported to kitchen work spot: ", global_position)
				
				farm_worker_state = FarmWorkerState.DELIVERING
				deliver_crops_to_kitchen()

func handle_kitchen_worker_arrival():
	var kitchen = get_kitchen()
	if kitchen and global_position.distance_to(kitchen.get_work_position()) < 2.0:
		# TELEPORT to actual kitchen work spot
		if kitchen.has_method("get_actual_work_spot"):
			global_position = kitchen.get_actual_work_spot()
			print("Kitchen worker teleported to work spot")
		
		if kitchen.can_convert_crops():
			start_working()

func start_working():
	current_state = State.WORKING
	work_timer = work_duration
	print("=== START WORKING ===")
	print(villager_name, " started working")
	print("Work timer set to: ", work_timer)
	print("Current state: ", State.keys()[current_state])

func complete_work():
	print("=== COMPLETE WORK ===")
	print(villager_name, " work completed")
	current_state = State.IDLE
	if assigned_job:
		print("Performing job action...")
		perform_job_action()
	else:
		print("No assigned job!")
	job_completed.emit()

func perform_job_action():
	print("=== PERFORM JOB ACTION ===")
	print("Job type: ", assigned_job.job_type)
	if assigned_job.job_type == Job.JobType.FARM_WORKER:
		print("Calling perform_farm_work()")
		perform_farm_work()
	elif assigned_job.job_type == Job.JobType.KITCHEN_WORKER:
		perform_kitchen_work()

func perform_farm_work():
	var farm = assigned_job.workplace
	if farm and farm.has_method("harvest_crop"):
		if farm.harvest_crop():
			carrying_crops = 1
			farm_worker_state = FarmWorkerState.GOING_TO_KITCHEN
			
			# Visual feedback - green when carrying crops
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.GREEN
			
			# TELEPORT back outside farm obstacle before pathfinding
			global_position = assigned_job.get_work_position()
			print("Teleported back outside farm: ", global_position)
			
			print(villager_name, " finished harvesting, teleported outside farm")

func perform_kitchen_work():
	var kitchen = get_kitchen()
	if kitchen and kitchen.has_method("convert_crops_to_meals"):
		if kitchen.convert_crops_to_meals():
			print(villager_name, " converted crops to meals in kitchen")
		else:
			print(villager_name, " couldn't convert - no crops or storage full")

func deliver_crops_to_kitchen():
	var kitchen = get_kitchen()
	if kitchen and kitchen.has_method("add_crops") and carrying_crops > 0:
		if kitchen.add_crops(carrying_crops):
			print(villager_name, " delivered ", carrying_crops, " crop(s) to kitchen")
			carrying_crops = 0
			farm_worker_state = FarmWorkerState.GOING_TO_FARM
			
			# Visual feedback - back to normal color
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.ORANGE
			
			# TELEPORT back outside kitchen obstacle before pathfinding
			if kitchen.has_method("get_work_position"):
				global_position = kitchen.get_work_position()
				print("Teleported back outside kitchen: ", global_position)
		else:
			print("Kitchen storage full!")
			go_to_house_idle()

func get_kitchen() -> Node3D:
	# Find the kitchen in the scene
	var village = get_parent()
	for child in village.get_children():
		if child.has_method("is_kitchen"):
			return child
	return null

func assign_job(job: Job):
	# Unassign from current job first
	if assigned_job:
		unassign_job()  # This will also disconnect signals
	
	assigned_job = job
	if job:
		job.assign_villager(self)
		print("=== JOB ASSIGNED DEBUG ===")
		print(villager_name, " assigned to job: ", job.job_type)
		print("Work position: ", job.get_work_position())
		print("Current villager position: ", global_position)
		print("Distance to work: ", global_position.distance_to(job.get_work_position()))
		
		# Connect to workplace moved signal
		connect_to_workplace_signals()
		
		# Reset work states when getting new job
		if job.job_type == Job.JobType.FARM_WORKER:
			farm_worker_state = FarmWorkerState.GOING_TO_FARM
			carrying_crops = 0
			
			# Reset color
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.ORANGE
	else:
		print(villager_name, " unassigned from job")

func unassign_job():
	if assigned_job:
		# Disconnect from workplace signals first
		disconnect_from_workplace_signals()
		
		assigned_job.unassign_villager()
		assigned_job = null
	
	# Reset states
	farm_worker_state = FarmWorkerState.GOING_TO_FARM
	carrying_crops = 0
	
	# Reset color
	var material = mesh_instance.material_override as StandardMaterial3D
	if material:
		material.albedo_color = Color.ORANGE
	
	print(villager_name, " job unassigned")
	

func connect_to_workplace_signals():
	disconnect_from_workplace_signals()  # Ensure no duplicate connections
	
	# Connect to workplace signals
	if assigned_job and assigned_job.workplace:
		var workplace = assigned_job.workplace
		if workplace.has_signal("building_moved"):
			workplace.building_moved.connect(_on_workplace_moved)
			print(villager_name, " connected to workplace movement signals")
	
	# Connect to house signals
	if home_house and home_house.has_signal("building_moved"):
		home_house.building_moved.connect(_on_house_moved)
		print(villager_name, " connected to house movement signals")

func disconnect_from_workplace_signals():
	# Disconnect from workplace signals
	if assigned_job and assigned_job.workplace:
		var workplace = assigned_job.workplace
		if workplace.has_signal("building_moved") and workplace.building_moved.is_connected(_on_workplace_moved):
			workplace.building_moved.disconnect(_on_workplace_moved)
			print(villager_name, " disconnected from workplace signals")
	
	# Disconnect from house signals  
	if home_house and home_house.has_signal("building_moved") and home_house.building_moved.is_connected(_on_house_moved):
		home_house.building_moved.disconnect(_on_house_moved)
		print(villager_name, " disconnected from house signals")

func _on_workplace_moved(building: BuildableBuilding, new_position: Vector2i):
	print("=== WORKPLACE MOVED ===")
	print(villager_name, "'s workplace moved to: ", new_position)
	
	# If we're currently walking, update our target immediately
	if current_state == State.WALKING:
		var new_target = assigned_job.get_work_position()
		print("Updating navigation from ", target_position, " to ", new_target)
		
		# Only update if the target actually changed significantly
		if target_position.distance_to(new_target) > 1.0:
			print("Target changed significantly - updating navigation")
			target_position = new_target
			navigation_agent.target_position = new_target
			print("New navigation target: ", navigation_agent.target_position)
		else:
			print("Target didn't change much - keeping current path")


func _on_house_moved(building: BuildableBuilding, new_position: Vector2i):
	print("=== HOUSE MOVED ===")
	print(villager_name, "'s house moved to: ", new_position)
	
	# If we're currently walking, check if we're walking to the house
	if current_state == State.WALKING:
		var house_target = home_house.global_position + Vector3(1, 0, 0)
		
		# Check if we're currently walking to the house (within reasonable distance of house target)
		if target_position.distance_to(house_target) > 1.0:
			# We were walking to the old house location - update to new location
			print("Updating house navigation from ", target_position, " to ", house_target)
			target_position = house_target
			navigation_agent.target_position = house_target
			print("New house navigation target: ", navigation_agent.target_position)
		else:
			print("Not walking to house - keeping current path")

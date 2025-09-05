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
var pending_unassignment: bool = false
var walking_toward: String = ""

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
	setup_collision_layers()  # Add this line
	setup_appearance()
	if navigation_agent:
		navigation_agent.target_reached.connect(_on_target_reached)
	call_deferred("setup_navigation")
	call_deferred("connect_house_signals")

func setup_collision_layers():
	# Put villagers on their own collision layer (layer 3)
	collision_layer = 4  # Layer 3 (binary 100 = decimal 4)
	
	# Villagers should only collide with ground (layer 1)
	# NOT with other villagers (layer 3) or buildings (layer 2)
	collision_mask = 1   # Only ground layer
	
	print("Villager collision setup - Layer: ", collision_layer, " Mask: ", collision_mask)


func connect_house_signals():
	if home_house and home_house.has_signal("building_moved"):
		home_house.building_moved.connect(_on_house_moved)
		print(villager_name, " connected to house movement signals in _ready")
	
func _exit_tree():
	disconnect_from_workplace_signals()

# villager.gd - Add this to setup_navigation()
func setup_navigation():
	if navigation_agent:
		navigation_agent.target_position = global_position
		
		# Navigation settings
		navigation_agent.path_desired_distance = 0.5
		navigation_agent.target_desired_distance = 0.5
		navigation_agent.radius = 0.3  # Villager radius
		navigation_agent.height = 1.6
		navigation_agent.max_speed = movement_speed
		
		# Enable avoidance so villagers try to go around each other
		navigation_agent.avoidance_enabled = true
		navigation_agent.avoidance_layers = 4  # Avoid other villagers (layer 3)
		navigation_agent.avoidance_mask = 4    # Be avoided by other villagers
		
		print("Navigation setup for ", villager_name, " with avoidance enabled")
	else:
		print("ERROR: No NavigationAgent3D found for ", villager_name)

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

func _physics_process(delta):
	match current_state:
		State.IDLE:
			handle_idle_state()
		State.WALKING:
			handle_walking_state(delta)
		State.WORKING:
			handle_working_state(delta)
	
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
	# If we have a pending unassignment and we're not carrying anything, complete it
	if pending_unassignment and carrying_crops == 0:
		complete_pending_unassignment()
		go_to_house_idle()
		return
	
	# If we have a pending unassignment but still carrying crops, continue delivery
	if pending_unassignment and carrying_crops > 0:
		print("Pending unassignment - finishing crop delivery")
		# Force kitchen delivery state
		farm_worker_state = FarmWorkerState.GOING_TO_KITCHEN
		handle_farm_worker_cycle()
		return
	
	# Normal idle behavior
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
				var farm = assigned_job.workplace
				if farm and farm.has_method("get_work_position"):
					var farm_entry = farm.get_work_position()
					if global_position.distance_to(farm_entry) > 1.5:
						print("Walking to farm entry point: ", farm_entry)
						walk_to_position(farm_entry, "farm")  # Explicitly specify destination
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
						walk_to_position(kitchen_entry, "kitchen")  # Explicitly specify destination
			else:
				farm_worker_state = FarmWorkerState.GOING_TO_FARM
				handle_farm_worker_cycle()


func handle_kitchen_worker_cycle():
	var kitchen = get_kitchen()
	if kitchen:
		var kitchen_pos = kitchen.get_work_position()
		if global_position.distance_to(kitchen_pos) > 1.5:
			walk_to_position(kitchen_pos, "kitchen")  # Explicitly specify destination
		elif kitchen.can_convert_crops():
			start_working()
	else:
		go_to_house_idle()

func go_to_house_idle():
	if home_house:
		var house_pos: Vector3
		
		# Use entry position if house has one, otherwise fallback
		if home_house.has_method("get_entry_position"):
			house_pos = home_house.get_entry_position()
		else:
			house_pos = home_house.global_position + Vector3(1, 0, 0)
		
		var distance_to_house = global_position.distance_to(house_pos)
		
		# Only walk if far from house OR if currently walking to wrong target
		if distance_to_house > 1 or (current_state == State.WALKING and target_position.distance_to(house_pos) > 1.0):
			print("=== WALK DEBUG ===")
			print(villager_name, " trying to walk to house entry at ", house_pos)
			print("Current position: ", global_position)
			print("Distance: ", distance_to_house)
			walk_to_position(house_pos, "house")


func handle_walking_state(delta):
	if not navigation_agent.is_navigation_finished():
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = (next_path_position - global_position).normalized()
		
		velocity = direction * movement_speed
		move_and_slide()
		
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

# Add this new function for safe teleporting
# villager.gd - Replace the safe_teleport_and_walk function
func safe_teleport_and_walk(teleport_pos: Vector3, walk_target: Vector3, destination_type: String = ""):
	print("=== SAFE TELEPORT ===")
	print("Teleporting from ", global_position, " to ", teleport_pos)
	print("Then walking to ", walk_target, " (", destination_type, ")")
	
	# Stop current movement
	current_state = State.IDLE
	velocity = Vector3.ZERO
	walking_toward = ""
	
	# Teleport
	global_position = teleport_pos
	global_position.y = 0.1
	
	# Force navigation system to acknowledge the new position
	navigation_agent.target_position = global_position
	
	# Wait multiple frames for navigation to fully update
	for i in range(3):
		await get_tree().process_frame
	
	# Force navigation map update
	NavigationServer3D.map_force_update(navigation_agent.get_navigation_map())
	await get_tree().process_frame
	
	print("Teleport complete, now walking to: ", walk_target)
	walk_to_position(walk_target, destination_type)

# Also improve the regular walk_to_position function
func walk_to_position(pos: Vector3, destination_type: String = ""):
	target_position = pos
	current_state = State.WALKING
	walking_toward = destination_type
	
	print("=== WALK DEBUG ===")
	print(villager_name, " walking from ", global_position, " to ", pos)
	print("Walking toward: ", walking_toward)
	print("Distance: ", global_position.distance_to(pos))
	
	global_position.y = 0.1
	pos.y = 0.1
	navigation_agent.target_position = pos
	
	await get_tree().process_frame
	
	if navigation_agent.is_navigation_finished():
		print("WARNING: No navigation path found")
		current_state = State.IDLE
		walking_toward = ""
	else:
		print("Navigation path found successfully")


func _on_target_reached():
	print(villager_name, " reached target! Was walking toward: ", walking_toward)
	current_state = State.IDLE
	walking_toward = ""
	arrived_at_destination.emit()
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
			if farm and farm.has_method("get_work_position"):
				var farm_entry = farm.get_work_position()
				if global_position.distance_to(farm_entry) < 2.0:
					if farm.can_harvest():
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
			
			# Visual feedback
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.GREEN
			
			print(villager_name, " finished harvesting, using safe teleport to exit")
			var kitchen = get_kitchen()
			if kitchen:
				var farm_exit = farm.get_work_position()
				var kitchen_entry = kitchen.get_work_position()
				safe_teleport_and_walk(farm_exit, kitchen_entry, "kitchen")

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
			
			# Visual feedback
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.ORANGE
			
			# Handle pending unassignment
			if pending_unassignment:
				complete_pending_unassignment()
				if home_house:
					var kitchen_exit = kitchen.get_work_position()
					var home_entry = home_house.get_entry_position()
					safe_teleport_and_walk(kitchen_exit, home_entry, "house")
				return
			
			# Continue working - teleport to kitchen exit then walk to farm
			farm_worker_state = FarmWorkerState.GOING_TO_FARM
			var farm = assigned_job.workplace
			if farm:
				var kitchen_exit = kitchen.get_work_position()
				var farm_entry = farm.get_work_position()
				safe_teleport_and_walk(kitchen_exit, farm_entry, "farm")

func get_kitchen() -> Node3D:
	# Find the kitchen in the scene
	var village = get_parent()
	for child in village.get_children():
		if child.has_method("is_kitchen"):
			return child
	return null

func assign_job(job: Job):
	# Unassign from current job first
	if assigned_job and assigned_job != job:
		unassign_job()
	
	# Unassign any other villager from this job
	if job.assigned_villager and job.assigned_villager != self:
		print("WARNING: Job already has worker ", job.assigned_villager.villager_name, " - unassigning them")
		job.assigned_villager.unassign_job()
	
	assigned_job = job
	if job:
		job.assign_villager(self)
		print("=== JOB ASSIGNED ===")
		print(villager_name, " assigned to job: ", job.job_type)
		print("Work position: ", job.get_work_position())
		print("Current villager position: ", global_position)
		
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
		# Check if villager is carrying crops and should finish delivery
		if carrying_crops > 0:
			print("=== SMART UNASSIGNMENT ===")
			print(villager_name, " is carrying ", carrying_crops, " crops")
			print("Will finish delivery before going home")
			pending_unassignment = true
			# Don't fully unassign yet - let them finish their delivery
			return
		else:
			print("=== IMMEDIATE UNASSIGNMENT ===")
			print(villager_name, " not carrying anything - going home immediately")
			# Disconnect from workplace signals first
			disconnect_from_workplace_signals()
			
			assigned_job.unassign_villager()
			assigned_job = null
			
			# Reset states
			farm_worker_state = FarmWorkerState.GOING_TO_FARM
			carrying_crops = 0
			pending_unassignment = false
			
			# Reset color
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_color = Color.ORANGE
			
			# If currently walking, redirect to home immediately
			if current_state == State.WALKING:
				print("Redirecting to home immediately")
				go_to_house_idle()
			
			print(villager_name, " job unassigned immediately")
	
	
func complete_pending_unassignment():
	if pending_unassignment:
		print("=== COMPLETING PENDING UNASSIGNMENT ===")
		print(villager_name, " finished delivery, now fully unassigning")
		
		# Disconnect from workplace signals
		disconnect_from_workplace_signals()
		
		if assigned_job:
			assigned_job.unassign_villager()
		assigned_job = null
		
		# Reset states
		farm_worker_state = FarmWorkerState.GOING_TO_FARM
		carrying_crops = 0
		pending_unassignment = false
		
		# Reset color
		var material = mesh_instance.material_override as StandardMaterial3D
		if material:
			material.albedo_color = Color.ORANGE
		
		print(villager_name, " fully unassigned after completing delivery")

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
	print("Currently walking toward: ", walking_toward)
	
	# Only update navigation if we were walking to the workplace
	if current_state == State.WALKING and (walking_toward == "farm" or walking_toward == "kitchen"):
		var new_target = Vector3.ZERO
		
		if walking_toward == "farm" and building == assigned_job.workplace:
			new_target = assigned_job.get_work_position()
		elif walking_toward == "kitchen" and building.has_method("is_kitchen"):
			new_target = building.get_work_position()
		
		if new_target != Vector3.ZERO and target_position.distance_to(new_target) > 1.0:
			print("Redirecting from ", target_position, " to ", new_target)
			target_position = new_target
			navigation_agent.target_position = new_target
		else:
			print("Workplace moved but target unchanged or very close")
	else:
		if current_state == State.WALKING:
			print("Walking toward '", walking_toward, "' - not affected by workplace move")
		else:
			print("Not walking - workplace move doesn't affect villager")

func _on_house_moved(building: BuildableBuilding, new_position: Vector2i):
	print("=== HOUSE MOVED ===")
	print(villager_name, "'s house moved to: ", new_position)
	print("Currently walking toward: ", walking_toward)
	
	# Only update navigation if we were specifically walking to the house
	if current_state == State.WALKING and walking_toward == "house":
		print("Was walking to house - redirecting to new house location")
		var new_house_target = building.get_entry_position()
		target_position = new_house_target
		navigation_agent.target_position = new_house_target
		print("Updated navigation to new house position: ", new_house_target)
	else:
		if current_state == State.WALKING:
			print("Walking toward '", walking_toward, "' - not affected by house move")
		else:
			print("Not walking - house move doesn't affect villager")

# Farm.gd - Simplified unlimited resources
extends BuildableBuilding

var work_positions: Array[Vector3] = []

func _ready():
	building_name = "Farm"
	building_size = Vector2i(2, 2)
	super._ready()
	
	setup_work_positions()
	setup_navigation_obstacle()
	
	# Register farm job and set meta
	var farm_job = Job.new(Job.JobType.FARM_WORKER, self)
	JobManager.register_job(farm_job)
	set_meta("job", farm_job)
	print("Farm job registered - UNLIMITED RESOURCES")
	
func setup_navigation_obstacle():
	# Add navigation obstacle so pathfinding goes around the farm
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	# For a 2x2 farm, use radius that covers the area
	nav_obstacle.radius = 1.5  # Slightly larger than half the diagonal of 2x2
	nav_obstacle.height = 1.0  # Height of the obstacle
	nav_obstacle.position = Vector3(1, 0, 1)  # Center of 2x2 farm
	print("Farm navigation obstacle created with radius: ", nav_obstacle.radius)

func setup_work_positions():
	var center = Vector3.ZERO
	work_positions = [
		center + Vector3(2.5, 0, 0),    # Right side
		center + Vector3(-1.5, 0, 0),   # Left side
		center + Vector3(0, 0, 1.5),    # Front
		center + Vector3(0, 0, -1.5)    # Back
	]

# In farm.gd
func get_work_position() -> Vector3:
	if work_positions.is_empty():
		return global_position
	return global_position + work_positions[0]

func get_actual_work_spot() -> Vector3:
	# Actual work location - center of farm (for teleporting when working)
	var work_spot = global_position + Vector3(1, 0, 1)  # Center of 2x2 farm
	print("Farm actual work spot: ", work_spot)
	return work_spot

func can_harvest() -> bool:
	# Always true - unlimited resources!
	return true

func harvest_crop() -> bool:
	# Always successful - the time limitation comes from villager work_duration
	print("Harvested crop from unlimited farm!")
	return true

# stone_node.gd - 3x3 stone quarry building
extends BuildableBuilding

@export var stored_stone: int = 0  # For future storage building integration
var work_positions: Array[Vector3] = []

func _ready():
	building_name = "Stone Quarry"
	building_size = Vector2i(3, 3)
	is_permanent = true 
	super._ready()
	
	setup_work_positions()
	setup_navigation_obstacle()
	
	# Register stone gathering job
	var stone_job = Job.new(Job.JobType.STONE_GATHERER, self)
	JobManager.register_job(stone_job)
	set_meta("job", stone_job)
	print("Stone Quarry job registered - UNLIMITED STONE RESOURCES")

func setup_navigation_obstacle():
	# Navigation obstacle for 3x3 building (same as heartwood)
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	nav_obstacle.radius = 2.0  # Covers 3x3 area
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(0, 0, 0)  # Center of 3x3
	print("Stone Quarry navigation obstacle created with radius: ", nav_obstacle.radius)

func setup_work_positions():
	# 3x3 building with obstacle radius 2.0 centered at (0, 0, 0)
	# Work positions outside the obstacle area
	var obstacle_center = Vector3(0, 0, 0)
	work_positions = [
		obstacle_center + Vector3(2.5, 0, 1),    # East side
		obstacle_center + Vector3(-2.5, 0, 0),   # West side  
		obstacle_center + Vector3(0, 0, 2.5),    # South side
		obstacle_center + Vector3(0, 0, -2.5)    # North side
	]
	print("Stone Quarry work positions set outside obstacle:")
	for i in range(work_positions.size()):
		print("  Position ", i, ": ", work_positions[i])

func get_work_position() -> Vector3:
	# Pathfinding target - outside the 3x3 obstacle
	if work_positions.is_empty():
		return global_position + Vector3(2.5, 0, 0)  # Fallback - east side
	return global_position + work_positions[0]  # Use east side

func get_actual_work_spot() -> Vector3:
	# Where villager teleports to when working (center of Stone Quarry)
	return global_position + Vector3(2,0,2)

func can_gather_stone() -> bool:
	# Always true - unlimited stone!
	return true

func gather_stone() -> bool:
	# Always successful - unlimited stone source
	print("Gathered stone from the Stone Quarry!")
	return true

func is_stone_quarry() -> bool:
	return true

func is_stone_source() -> bool:
	return true

# For future storage building integration
func get_available_stone() -> int:
	return 999999  # Unlimited

func extract_stone(amount: int) -> int:
	# Always returns the requested amount - unlimited source
	return amount

extends BuildableBuilding

func _ready():
	building_name = "House"
	building_size = Vector2i(1, 2)  # 1x2 house
	super._ready()
	setup_navigation_obstacle()


func setup_navigation_obstacle():
	# Add navigation obstacle so pathfinding goes around the house
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	# For a 1x2 house, use radius that covers the area
	nav_obstacle.radius = 1.2  # Covers the 1x2 area
	nav_obstacle.height = 1.5  # Height of the obstacle
	nav_obstacle.position = Vector3(0.5, 0, 1)  # Center of 1x2 house
	print("House navigation obstacle created with radius: ", nav_obstacle.radius)

func get_entry_position() -> Vector3:
	# Entry point - east side of house, outside collision
	return global_position + Vector3(1.5, 0, 1)  # East of 1x2 house

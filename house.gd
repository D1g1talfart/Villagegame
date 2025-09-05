extends BuildableBuilding

func _ready():
	building_name = "House"
	building_size = Vector2i(1, 2)  # 1x2 house
	super._ready()
	setup_navigation_obstacle()

# house.gd - Add this simple function back
func get_entry_position() -> Vector3:
	# Simple position outside the house for villagers to stand
	return global_position + Vector3(1.5, 0, 0)  # East of house
# Add this to each building's setup_navigation_obstacle() function
# farm.gd, house.gd, Kitchen.gd - add this line in setup_navigation_obstacle()

func setup_navigation_obstacle():
	var nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavigationObstacle"
	add_child(nav_obstacle)
	
	# Configure obstacle (existing code)
	nav_obstacle.radius = 1.5  # or appropriate radius for each building
	nav_obstacle.height = 1.0
	nav_obstacle.position = Vector3(1, 0, 1)  # or appropriate position
	
	# ADD THIS LINE - put obstacle in a group for tracking
	nav_obstacle.add_to_group("navigation_obstacles")
	
	print("Farm navigation obstacle created and added to group")

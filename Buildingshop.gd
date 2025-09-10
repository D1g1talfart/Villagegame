# BuildingShop.gd - Replace with this updated version
extends Node

signal building_purchased(building_data: BuildingData)

var player_level: int = 1
var player_wood: int = 10
var player_stone: int = 5
var player_meals: int = 0

var available_buildings: Array[BuildingData] = []
var building_counts: Dictionary = {}  # BuildingType -> count

func _ready():
	print("BuildingShop: _ready() called")
	initialize_building_counts()
	setup_building_data()
	print("BuildingShop: Available buildings count: ", available_buildings.size())

func initialize_building_counts():
	# Initialize all building counts to 0
	for building_type in BuildingData.BuildingType.values():
		building_counts[building_type] = 0
	
	# Set initial building counts (what's already on the map)
	building_counts[BuildingData.BuildingType.FARM] = 1      # One farm already exists
	building_counts[BuildingData.BuildingType.HOUSE] = 1     # One house already exists
	# Kitchen doesn't count as it's permanent
	
	print("BuildingShop: Initial building counts: ", building_counts)

func setup_building_data():
	print("BuildingShop: Setting up building data...")
	available_buildings.clear()
	
	# FARM - First is on map, 2nd needs level 3, 3rd needs level 7, then every 3 levels
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.FARM, 
		"Farm", 
		"Produces crops for villagers to harvest",
		[1, 3, 7, 10, 13, 16, 19],  # level_reqs parameter (4th)
		3,                          # wood
		0,                          # stone  
		0,                          # meals
		Vector2i(2, 2),            # building_size
		"res://farm.tscn"          # path
		# max_count defaults to -1 (unlimited)
	))
	
	# HOUSE - Gets easier: level 1, 2, 3, 4, 5... (one per level after first)
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.HOUSE, 
		"House", 
		"Provides housing for villagers",
		[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],  # level_reqs parameter (4th)
		5,                                  # wood
		2,                                  # stone
		0,                                  # meals
		Vector2i(1, 2),                    # building_size
		"res://house.tscn"                 # path
		# max_count defaults to -1 (unlimited)
	))
	
	# BAKERY - Single building, high level requirement
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.BAKERY, 
		"Bakery", 
		"Converts crops into bread more efficiently",
		[5],                # level_reqs parameter (4th) - only one level
		8,                  # wood
		4,                  # stone
		2,                  # meals
		Vector2i(2, 2),     # building_size
		"",                 # path (empty since not implemented)
		1                   # max_count = 1
	))
	
	# LUMBER MILL - Two maximum, increasing requirements
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.LUMBER_MILL, 
		"Lumber Mill", 
		"Produces wood from nearby trees",
		[2, 6],             # level_reqs parameter (4th) - first needs level 2, second needs level 6
		0,                  # wood
		6,                  # stone
		3,                  # meals
		Vector2i(2, 3),     # building_size
		"",                 # path
		2                   # max_count = 2
	))
	
	# WORKSHOP - Single building, very high level
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.WORKSHOP, 
		"Workshop", 
		"Crafts tools and advanced items",
		[8],                # level_reqs parameter (4th) - single workshop, needs level 8
		12,                 # wood
		8,                  # stone
		5,                  # meals
		Vector2i(3, 2),     # building_size
		"",                 # path
		1                   # max_count = 1
	))
	
	# MINE - Multiple mines, but expensive level-wise
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.MINE, 
		"Stone Mine", 
		"Extracts stone and minerals",
		[4, 7, 11, 15],     # level_reqs parameter (4th) - progressive requirements, big jumps
		10,                 # wood
		0,                  # stone
		4,                  # meals
		Vector2i(2, 2),     # building_size
		""                  # path
		# max_count defaults to -1 (unlimited)
	))
	
	# TAVERN - Single building, end-game
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.TAVERN, 
		"Tavern", 
		"Attracts new villagers to your settlement",
		[10],               # level_reqs parameter (4th) - very high level requirement
		15,                 # wood
		10,                 # stone
		8,                  # meals
		Vector2i(3, 3),     # building_size
		"",                 # path
		1                   # max_count = 1
	))
	
	print("BuildingShop: Added ", available_buildings.size(), " buildings with progressive requirements")
func get_building_count(building_type: BuildingData.BuildingType) -> int:
	return building_counts.get(building_type, 0)

func can_build_more(building_data: BuildingData) -> bool:
	var current_count = get_building_count(building_data.building_type)
	
	# Check max building limit
	if building_data.max_buildings != -1 and current_count >= building_data.max_buildings:
		return false
	
	return true

func get_next_level_requirement(building_data: BuildingData) -> int:
	var current_count = get_building_count(building_data.building_type)
	return building_data.get_level_requirement_for_count(current_count)

func can_purchase_building(building_data: BuildingData) -> bool:
	if not can_build_more(building_data):
		return false
	
	var required_level = get_next_level_requirement(building_data)
	var meets_level = player_level >= required_level
	var can_afford = building_data.can_afford(player_wood, player_stone, player_meals)
	
	return meets_level and can_afford

func purchase_building(building_data: BuildingData) -> bool:
	if can_purchase_building(building_data):
		player_wood -= building_data.cost_wood
		player_stone -= building_data.cost_stone
		player_meals -= building_data.cost_meals
		
		# Don't increment count yet - wait until actually placed
		# building_counts[building_data.building_type] += 1
		
		# Enter placement mode
		BuildModeManager.enter_placement_mode(building_data)
		
		building_purchased.emit(building_data)
		print("Purchased: ", building_data.display_name, " - now place it on the map!")
		return true
	return false

func get_resources_text() -> String:
	return "Meals: %d | Wood: %d" % [player_meals, player_wood]

# Debug function to set player level for testing
func set_player_level(level: int):
	player_level = level
	print("Player level set to: ", level)

func confirm_building_placed(building_data: BuildingData):
	building_counts[building_data.building_type] += 1
	print("Building placed and counted: ", building_data.display_name, " (Count now: ", building_counts[building_data.building_type], ")")

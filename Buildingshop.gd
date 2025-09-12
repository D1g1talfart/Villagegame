# BuildingShop.gd - Updated version with your Level 1-4 progression
extends Node

signal building_purchased(building_data: BuildingData)

var player_level: int = 1
var player_wood: int = 0  # Starting with more wood for testing
var player_stone: int = 0
var player_gold: int = 0  # Replaced meals with gold

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
	
	# HOUSE - 3 at level 1, 4th at level 2, 5th at level 4
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.HOUSE, 
		"Villager Home", 
		"Houses for your villagers to live in",
		[1, 1, 1, 2, 4],    # 3 houses at level 1, 4th at level 2, 5th at level 4
		5,                  # wood cost
		0,                  # stone cost  
		0,                  # gold cost
		Vector2i(1, 2),     # building_size
		"res://house.tscn", # path
		5                   # max 5 houses total
	))
	
	# GOLD COIN STORAGE - Available at level 1
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.GOLD_STORAGE, 
		"Gold Coin Storage", 
		"Stores your gold coins safely",
		[1],                # Available at level 1
		10,                 # wood cost
		0,                  # stone cost
		0,                  # gold cost
		Vector2i(2, 2),     # building_size
		"res://gold_storage.tscn", # path 
		1                   # max 1
	))
	
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.STONE_STORAGE, 
		"Stone Storage", 
		"Stores stone and building materials",
		[2, 3],                    # Available at level 2
		10,                     # wood cost
		0,                      # stone cost
		200,                    # gold cost
		Vector2i(2, 2),         # building_size
		"res://stone_storage.tscn",  # <-- ADD THIS PATH
		2                       # max 2
))
	
	# RABBIT HUTCH - Available at level 3
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.RABBIT_HUTCH, 
		"Rabbit Hutch", 
		"Raises rabbits for food and resources",
		[3],                # Available at level 3
		20,                 # wood cost
		5,                  # stone cost
		500,                # gold cost
		Vector2i(2, 2),     # building_size
		"",                 # path
		1                   # max 1
	))
	
	# WAREHOUSE - Available at level 3
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.WAREHOUSE, 
		"Warehouse", 
		"Large storage for all your goods",
		[3],                # Available at level 3
		30,                 # wood cost
		15,                 # stone cost
		500,                # gold cost
		Vector2i(3, 2),     # building_size
		"",                 # path
		1                   # max 1
	))
	
	# ORNAMENT WORKSHOP - Available at level 3
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.ORNAMENT_WORKSHOP, 
		"Ornament Workshop", 
		"Crafts decorative items and ornaments",
		[3],                # Available at level 3
		30,                 # wood cost
		20,                 # stone cost
		800,                # gold cost
		Vector2i(2, 2),     # building_size
		"",                 # path
		1                   # max 1
	))
	
	# FARM - Second farm available at level 4
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.FARM, 
		"Farm", 
		"Produces crops for your villagers",
		[1, 4],             # First farm exists, second at level 4
		30,                 # wood cost (more expensive than first)
		0,                  # stone cost  
		0,                  # gold cost
		Vector2i(2, 2),     # building_size
		"res://farm.tscn",  # path
		2                   # max 2 farms
	))
	
	# PLANK STORAGE - Available at level 4
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.PLANK_STORAGE, 
		"Plank Storage", 
		"Specialized storage for processed wood planks",
		[4],                # Available at level 4
		50,                 # wood cost
		30,                 # stone cost
		1500,               # gold cost
		Vector2i(2, 3),     # building_size
		"",                 # path
		1                   # max 1
	))
	
	# PLANK WORKSHOP - Available at level 4
	available_buildings.append(BuildingData.new(
		BuildingData.BuildingType.PLANK_WORKSHOP, 
		"Plank Workshop", 
		"Converts raw wood into refined planks",
		[4],                # Available at level 4
		30,                 # wood cost
		50,                 # stone cost
		1500,               # gold cost
		Vector2i(2, 2),     # building_size
		"",                 # path
		1                   # max 1
	))
	
	print("BuildingShop: Added ", available_buildings.size(), " buildings for levels 1-4")

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
	var can_afford = building_data.can_afford(player_wood, player_stone, player_gold)  # Changed from meals to gold
	
	return meets_level and can_afford

func purchase_building(building_data: BuildingData) -> bool:
	if can_purchase_building(building_data):
		# Actually deduct resources from storage buildings instead of just counters
		var success = deduct_resources(building_data.cost_wood, building_data.cost_stone, building_data.cost_gold)
		
		if success:
			# Enter placement mode
			BuildModeManager.enter_placement_mode(building_data)
			building_purchased.emit(building_data)
			print("Purchased: ", building_data.display_name, " - now place it on the map!")
			return true
		else:
			print("Failed to deduct resources from storage!")
			return false
	return false

# New function to actually deduct from storage buildings
func deduct_resources(wood_needed: int, stone_needed: int, gold_needed: int) -> bool:
	var wood_storage = find_wood_storage()
	var stone_storage = find_stone_storage() 
	var gold_storage = find_gold_storage()
	
	# Check if we can deduct the resources
	var wood_available = wood_storage.stored_wood if wood_storage else 0
	var stone_available = stone_storage.stored_stone if stone_storage else 0
	var gold_available = gold_storage.stored_gold if gold_storage else 0
	
	if wood_available < wood_needed or stone_available < stone_needed or gold_available < gold_needed:
		return false
	
	# Actually deduct the resources
	if wood_needed > 0 and wood_storage:
		wood_storage.stored_wood -= wood_needed
		print("Deducted ", wood_needed, " wood. Storage now: ", wood_storage.stored_wood)
	
	if stone_needed > 0 and stone_storage:
		stone_storage.stored_stone -= stone_needed
		print("Deducted ", stone_needed, " stone. Storage now: ", stone_storage.stored_stone)
	
	if gold_needed > 0 and gold_storage:
		gold_storage.stored_gold -= gold_needed
		print("Deducted ", gold_needed, " gold. Storage now: ", gold_storage.stored_gold)
	
	return true

func get_resources_text() -> String:
	return "Gold: %d | Wood: %d | Stone: %d" % [player_gold, player_wood, player_stone]  # Updated to show gold instead of meals

# Debug function to set player level for testing
func set_player_level(level: int):
	player_level = level
	print("Player level set to: ", level)

func confirm_building_placed(building_data: BuildingData):
	building_counts[building_data.building_type] += 1
	print("Building placed and counted: ", building_data.display_name, " (Count now: ", building_counts[building_data.building_type], ")")

# Helper function to add resources for testing
func add_resources(wood: int = 0, stone: int = 0, gold: int = 0):
	player_wood += wood
	player_stone += stone  
	player_gold += gold
	print("Resources added. Current: Wood=%d, Stone=%d, Gold=%d" % [player_wood, player_stone, player_gold])

func find_wood_storage():
	var wood_storages = get_tree().get_nodes_in_group("wood_storage")
	return wood_storages[0] if wood_storages.size() > 0 else null

func find_gold_storage():
	var gold_storages = get_tree().get_nodes_in_group("gold_storage")
	return gold_storages[0] if gold_storages.size() > 0 else null

func find_stone_storage():
	var stone_storages = get_tree().get_nodes_in_group("stone_storage")
	return stone_storages[0] if stone_storages.size() > 0 else null

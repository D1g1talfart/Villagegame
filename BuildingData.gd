# BuildingData.gd - Fix the constructor signature
extends RefCounted
class_name BuildingData

enum BuildingType { FARM, HOUSE, BAKERY, LUMBER_MILL, WORKSHOP, MINE, TAVERN }

var building_type: BuildingType
var display_name: String
var description: String
var cost_wood: int = 0
var cost_stone: int = 0
var cost_meals: int = 0
var level_requirements: Array[int] = [1]  # Array of level requirements for 1st, 2nd, 3rd... building
var max_buildings: int = -1  # -1 means unlimited
var size: Vector2i
var scene_path: String
var icon_texture: String = ""

# FIXED constructor signature - level_reqs is now parameter 4, max_count is parameter 10
func _init(type: BuildingType, name: String, desc: String, level_reqs: Array[int], wood: int = 0, stone: int = 0, meals: int = 0, building_size: Vector2i = Vector2i(1,1), path: String = "", max_count: int = -1):
	building_type = type
	display_name = name
	description = desc
	level_requirements = level_reqs
	max_buildings = max_count
	cost_wood = wood
	cost_stone = stone
	cost_meals = meals
	size = building_size
	scene_path = path
	print("Created BuildingData: ", name, " with ", level_requirements.size(), " level tiers")

func get_level_requirement_for_count(current_count: int) -> int:
	# If we have more buildings than defined requirements, use the last requirement
	if current_count < level_requirements.size():
		return level_requirements[current_count]
	elif level_requirements.size() > 0:
		return level_requirements[-1]  # Use last defined requirement
	else:
		return 1  # Fallback

func can_afford(wood: int, stone: int, meals: int) -> bool:
	return wood >= cost_wood and stone >= cost_stone and meals >= cost_meals

func get_cost_text() -> String:
	var costs = []
	if cost_wood > 0:
		costs.append("%d Wood" % cost_wood)
	if cost_stone > 0:
		costs.append("%d Stone" % cost_stone)
	if cost_meals > 0:
		costs.append("%d Meals" % cost_meals)
	
	if costs.is_empty():
		return "Free"
	return " + ".join(costs)

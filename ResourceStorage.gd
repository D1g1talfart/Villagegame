# Create ResourceStorage.gd
extends RefCounted
class_name ResourceStorage

var crops: int = 0
var meals: int = 0
var max_crops: int
var max_meals: int

func _init(max_crops_count: int, max_meals_count: int):
	max_crops = max_crops_count
	max_meals = max_meals_count

func add_crops(amount: int) -> int:
	var can_add = min(amount, max_crops - crops)
	crops += can_add
	return can_add  # Returns how much was actually added

func remove_crops(amount: int) -> int:
	var can_remove = min(amount, crops)
	crops -= can_remove
	return can_remove

func add_meals(amount: int) -> int:
	var can_add = min(amount, max_meals - meals)
	meals += can_add
	return can_add

func remove_meals(amount: int) -> int:
	var can_remove = min(amount, meals)
	meals -= can_remove
	return can_remove

func can_accept_crops(amount: int) -> bool:
	return crops + amount <= max_crops

func can_accept_meals(amount: int) -> bool:
	return meals + amount <= max_meals

func get_status() -> String:
	return "Crops: %d/%d, Meals: %d/%d" % [crops, max_crops, meals, max_meals]

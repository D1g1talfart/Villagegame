# GridPathfinder.gd
extends RefCounted
class_name GridPathfinder

class PathNode:
	var position: Vector2i
	var g_cost: float = 0.0  # Distance from start
	var h_cost: float = 0.0  # Distance to goal
	var f_cost: float = 0.0  # g_cost + h_cost
	var parent: PathNode = null
	
	func _init(pos: Vector2i):
		position = pos
	
	func calculate_f_cost():
		f_cost = g_cost + h_cost

var grid_size: Vector2i
var blocked_tiles: Dictionary = {}

func _init(size: Vector2i):
	grid_size = size

func set_blocked_tiles(tiles: Dictionary):
	blocked_tiles = tiles.duplicate()
	print("GridPathfinder: Set ", blocked_tiles.size(), " blocked tiles")

func is_tile_walkable(pos: Vector2i) -> bool:
	# Check bounds
	if pos.x < 0 or pos.y < 0 or pos.x >= grid_size.x or pos.y >= grid_size.y:
		return false
	
	# Check if blocked
	return not (pos in blocked_tiles)

func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	
	# Straight directions (always allowed if walkable)
	var straight_directions = [
		Vector2i(0, 1),   # North
		Vector2i(1, 0),   # East  
		Vector2i(0, -1),  # South
		Vector2i(-1, 0)   # West
	]
	
	# Diagonal directions (need corner checking)
	var diagonal_directions = [
		Vector2i(1, 1),   # Northeast
		Vector2i(1, -1),  # Southeast
		Vector2i(-1, -1), # Southwest
		Vector2i(-1, 1)   # Northwest
	]
	
	# Add straight neighbors if walkable
	for dir in straight_directions:
		var neighbor_pos = pos + dir
		if is_tile_walkable(neighbor_pos):
			neighbors.append(neighbor_pos)
	
	# Add diagonal neighbors only if they don't cut through corners
	for dir in diagonal_directions:
		var neighbor_pos = pos + dir
		if is_tile_walkable(neighbor_pos) and can_move_diagonally(pos, neighbor_pos):
			neighbors.append(neighbor_pos)
	
	return neighbors

# Add this new function to check diagonal movement validity
func can_move_diagonally(from: Vector2i, to: Vector2i) -> bool:
	var diff = to - from
	
	# Only check diagonal moves
	if abs(diff.x) != 1 or abs(diff.y) != 1:
		return true  # Not a diagonal move
	
	# For diagonal movement, both adjacent straight tiles must be walkable
	# This prevents cutting through building corners
	var side1 = from + Vector2i(diff.x, 0)  # Horizontal adjacent
	var side2 = from + Vector2i(0, diff.y)  # Vertical adjacent
	
	# DEBUG: Print what we're checking
	print("Diagonal check from ", from, " to ", to)
	print("  Checking side1: ", side1, " (walkable: ", is_tile_walkable(side1), ")")
	print("  Checking side2: ", side2, " (walkable: ", is_tile_walkable(side2), ")")
	
	if not is_tile_walkable(side1) or not is_tile_walkable(side2):
		print("  BLOCKED diagonal movement - can't cut through corner")
		return false  # Can't cut through corner
	
	print("  ALLOWED diagonal movement")
	return true

func heuristic(a: Vector2i, b: Vector2i) -> float:
	# Manhattan distance with diagonal movement
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return max(dx, dy)

func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	# Add debug info at the start
	print("=== PATHFINDING DEBUG ===")
	print("Start: ", start, " (walkable: ", is_tile_walkable(start), ")")
	print("Goal: ", goal, " (walkable: ", is_tile_walkable(goal), ")")
	
	if not is_tile_walkable(start):
		print("GridPathfinder: Start position not walkable: ", start)
		# Check what's blocking the start position
		if start in blocked_tiles:
			var blocker = blocked_tiles[start]
			print("  Blocked by: ", blocker.building_name if blocker else "unknown building")
		
		return []
	
	if not is_tile_walkable(goal):
		print("GridPathfinder: Goal position not walkable: ", goal)
		# Try to find a walkable tile near the goal
		goal = find_nearest_walkable_tile(goal)
		if goal == Vector2i(-1, -1):
			print("GridPathfinder: No walkable tile near goal")
			return []
		print("GridPathfinder: Using nearest walkable goal: ", goal)
	
	var open_set: Array[PathNode] = []
	var closed_set: Dictionary = {}
	
	var start_node = PathNode.new(start)
	start_node.g_cost = 0
	start_node.h_cost = heuristic(start, goal)
	start_node.calculate_f_cost()
	open_set.append(start_node)
	
	while open_set.size() > 0:
		# Find node with lowest f_cost
		var current = open_set[0]
		for node in open_set:
			if node.f_cost < current.f_cost:
				current = node
		
		open_set.erase(current)
		closed_set[current.position] = current
		
		# Check if we reached the goal
		if current.position == goal:
			return reconstruct_path(current)
		
		# Check neighbors
		for neighbor_pos in get_neighbors(current.position):
			if neighbor_pos in closed_set:
				continue
			
			var neighbor = PathNode.new(neighbor_pos)
			var tentative_g_cost = current.g_cost + get_distance(current.position, neighbor_pos)
			
			var existing_node = null
			for node in open_set:
				if node.position == neighbor_pos:
					existing_node = node
					break
			
			if existing_node == null or tentative_g_cost < existing_node.g_cost:
				neighbor.g_cost = tentative_g_cost
				neighbor.h_cost = heuristic(neighbor_pos, goal)
				neighbor.calculate_f_cost()
				neighbor.parent = current
				
				if existing_node == null:
					open_set.append(neighbor)
				else:
					# Update existing node
					existing_node.g_cost = neighbor.g_cost
					existing_node.h_cost = neighbor.h_cost
					existing_node.f_cost = neighbor.f_cost
					existing_node.parent = neighbor.parent
	
	print("GridPathfinder: No path found from ", start, " to ", goal)
	return []

func find_nearest_walkable_tile(pos: Vector2i, max_radius: int = 3) -> Vector2i:
	for radius in range(1, max_radius + 1):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if abs(x) == radius or abs(y) == radius:  # Only check perimeter
					var check_pos = pos + Vector2i(x, y)
					if is_tile_walkable(check_pos):
						return check_pos
	return Vector2i(-1, -1)  # Not found

func get_distance(a: Vector2i, b: Vector2i) -> float:
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	
	# Diagonal movement costs more
	if dx > 0 and dy > 0:
		return 1.414  # sqrt(2)
	else:
		return 1.0

func reconstruct_path(node: PathNode) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = node
	
	while current != null:
		path.push_front(current.position)
		current = current.parent
	
	return path

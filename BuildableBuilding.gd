# Simplified BuildableBuilding.gd
extends StaticBody3D
class_name BuildableBuilding

signal building_selected(building)
signal building_moved(building, new_position)

@export var building_name: String = "Building"
@export var building_size: Vector2i = Vector2i(1, 1)
@export var is_permanent: bool = false

var is_selected: bool = false
var original_material: Material
var highlight_material: StandardMaterial3D
var grid_position: Vector2i = Vector2i(-999, -999)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
	setup_materials()
	setup_collision()
	BuildModeManager.building_selection_changed.connect(_on_building_selection_changed)
	print("Building ready: ", building_name)

func setup_collision():
	# Make sure buildings are on collision layer 2 (for clicking only)
	collision_layer = 2
	collision_mask = 0

# Updated setup_materials() function in BuildableBuilding.gd
func setup_materials():
	# Create highlight material
	highlight_material = StandardMaterial3D.new()
	highlight_material.albedo_color = Color.YELLOW
	highlight_material.emission = Color.YELLOW * 0.3
	
	if not mesh_instance:
		print("No mesh_instance found for: ", building_name)
		return
	
	# Check for existing materials in multiple places
	original_material = null
	
	# First, check material_override
	if mesh_instance.material_override:
		original_material = mesh_instance.material_override
		print("Found material_override for: ", building_name)
	
	# If no material_override, check the mesh surface material
	elif mesh_instance.mesh and mesh_instance.mesh.surface_get_material(0):
		original_material = mesh_instance.mesh.surface_get_material(0)
		print("Found surface material for: ", building_name)
		# Move it to material_override so we can control it properly
		mesh_instance.material_override = original_material
	
	# Last resort: create a default material
	if not original_material:
		print("No existing material found for: ", building_name, " - creating default")
		var default_material = StandardMaterial3D.new()
		default_material.albedo_color = Color.WHITE  # Just white as fallback
		mesh_instance.material_override = default_material
		original_material = default_material
	
	print("Material setup complete for: ", building_name, " - Color: ", original_material.albedo_color if original_material is StandardMaterial3D else "Unknown")

func set_selected(selected: bool):
	is_selected = selected
	
	if mesh_instance:
		if selected:
			mesh_instance.material_override = highlight_material
			print("Highlighted: ", building_name)
		else:
			mesh_instance.material_override = original_material
			print("Restored material for: ", building_name)

func _on_building_selection_changed(selected_building):
	set_selected(selected_building == self)

func move_to_grid_position(new_grid_pos: Vector2i):
	# grid_position is now set by BuildModeManager before this is called
	# Just update the visual position
	position = Vector3(new_grid_pos.x, position.y, new_grid_pos.y)
	building_moved.emit(self, new_grid_pos)
	print("Moved ", building_name, " to ", new_grid_pos)

func get_occupied_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(building_size.x):
		for y in range(building_size.y):
			tiles.append(Vector2i(grid_position.x + x, grid_position.y + y))
	
	# DEBUG: Print house tiles when house is moved
	if building_name == "House":
		print("House at ", grid_position, " occupies tiles: ", tiles)
	
	return tiles

extends Node3D

@onready var camera = $Camera3D

# Camera settings
var zoom_speed = 2.0
var pan_speed = 10.0
var min_zoom = 5.0
var max_zoom = 50.0
var map_size = 49  # Number of tiles
var map_center = Vector3(24, 0, 24)  # Center of your 49x49 map

# Touch/mouse input tracking
var is_dragging = false
var drag_start_position = Vector2.ZERO
var camera_start_position = Vector3.ZERO

func _ready():
	setup_camera()

func setup_camera():
	# Position camera at the center of your map
	position = map_center
	
	# Set up the camera
	camera.position = Vector3(0, 25, 25)
	camera.rotation_degrees = Vector3(-45, 45, 0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0

func _input(event):
	handle_zoom(event)
	handle_pan_start(event)
	handle_pan_drag(event)
	handle_pan_end(event)

func handle_zoom(event):
	# ADDED: Don't process zoom if any UI is open
	if is_any_ui_open():
		return
		
	var zoom_delta = 0.0
	
	# Desktop mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_delta = -zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_delta = zoom_speed
	
	# Mobile pinch (you'll need to implement gesture detection for this)
	# For now, we'll add touch zoom buttons later
	
	if zoom_delta != 0:
		camera.size = clamp(camera.size + zoom_delta, min_zoom, max_zoom)

# Add this function to camera_controller.gd
func is_any_ui_open() -> bool:
	# Find the village scene to access mobile_ui
	var village = get_tree().current_scene
	if village and village.has_method("is_any_ui_open"):
		return village.is_any_ui_open()
	
	# Fallback check
	var mobile_ui = get_tree().current_scene.get_node_or_null("MobileUI")
	if mobile_ui and mobile_ui.building_shop_ui and mobile_ui.building_shop_ui.visible:
		return true
	
	return false

func handle_pan_start(event):
	# Desktop - right mouse button or middle mouse
	if event is InputEventMouseButton:
		if (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE) and event.pressed:
			start_drag(event.position)
	
	# Mobile - single touch
	elif event is InputEventScreenTouch:
		if event.pressed and event.index == 0:  # First finger
			start_drag(event.position)

func handle_pan_drag(event):
	if not is_dragging:
		return
	
	var current_position = Vector2.ZERO
	
	# Get current position based on input type
	if event is InputEventMouseMotion:
		current_position = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		current_position = event.position
	else:
		return
	
	# Calculate movement - BACK TO YOUR ORIGINAL (this was correct!)
	var drag_delta = drag_start_position - current_position
	var movement_scale = camera.size * 0.001
	
	# Convert screen movement to world movement (accounting for isometric view)
	var world_delta = Vector3(
		(drag_delta.x + drag_delta.y) * movement_scale,
		0,
		(drag_delta.y - drag_delta.x) * movement_scale
	)
	
	# Apply movement with bounds checking
	var new_position = camera_start_position + world_delta
	position = clamp_camera_position(new_position)

func handle_pan_end(event):
	# Desktop
	if event is InputEventMouseButton:
		if (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE) and not event.pressed:
			end_drag()
	
	# Mobile
	elif event is InputEventScreenTouch:
		if not event.pressed and event.index == 0:
			end_drag()

func start_drag(start_pos: Vector2):
	is_dragging = true
	drag_start_position = start_pos
	camera_start_position = position

func end_drag():
	is_dragging = false

func clamp_camera_position(pos: Vector3) -> Vector3:
	# Measured camera bounds with small buffer
	var buffer = 2.0
	var min_x = 17.0 - buffer
	var max_x = 66.0 + buffer
	var min_z = -8.0 - buffer  
	var max_z = 41.0 + buffer
	
	return Vector3(
		clamp(pos.x, min_x, max_x),
		pos.y,
		clamp(pos.z, min_z, max_z)
	)

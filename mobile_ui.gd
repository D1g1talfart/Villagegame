# Create a new scene with Control as root, call it "MobileUI"
# Add this script to the Control node:

extends Control

signal zoom_in_pressed
signal zoom_out_pressed

@onready var zoom_in_button = $VBoxContainer/ZoomIn
@onready var zoom_out_button = $VBoxContainer/ZoomOut

func _ready():
	setup_ui()

func setup_ui():
	# Create zoom buttons
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 1.0
	vbox.anchor_right = 1.0
	vbox.anchor_top = 0.0
	vbox.anchor_bottom = 0.0
	vbox.offset_left = -80
	vbox.offset_top = 20
	add_child(vbox)
	
	# Zoom in button
	var zoom_in = Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(60, 60)
	zoom_in.pressed.connect(_on_zoom_in_pressed)
	vbox.add_child(zoom_in)
	
	# Zoom out button
	var zoom_out = Button.new()
	zoom_out.text = "-"
	zoom_out.custom_minimum_size = Vector2(60, 60)
	zoom_out.pressed.connect(_on_zoom_out_pressed)
	vbox.add_child(zoom_out)

func _on_zoom_in_pressed():
	zoom_in_pressed.emit()

func _on_zoom_out_pressed():
	zoom_out_pressed.emit()

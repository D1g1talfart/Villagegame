extends Control

signal zoom_in_pressed
signal zoom_out_pressed
signal build_mode_toggled
signal shop_button_pressed

var build_mode_button: Button
var shop_button: Button
var resource_label: Label
var building_shop_ui: Control
var shop_buildings_vbox: VBoxContainer  # Direct reference
var shop_resources_label: Label  


func _ready():
	setup_ui()
	BuildModeManager.build_mode_toggled.connect(_on_build_mode_changed)
	BuildModeManager.build_mode_toggled.connect(_on_build_mode_toggled_refresh_shop)
	
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(update_resource_display)
	timer.autostart = true
	add_child(timer)

func setup_ui():
	# Create main UI container
	var main_container = VBoxContainer.new()
	main_container.anchor_left = 1.0
	main_container.anchor_right = 1.0
	main_container.anchor_top = 0.0
	main_container.anchor_bottom = 1.0
	main_container.offset_left = -150
	main_container.offset_top = 20
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# Resource Display (top section)
	create_resource_display(main_container)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 50)
	main_container.add_child(spacer1)
	
	# Zoom Controls
	create_zoom_controls(main_container)
	
	# Another spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 100)
	main_container.add_child(spacer2)
	
	# Build Mode Button
	create_build_mode_button(main_container)
	
	# Shop Button (NEW)
	create_shop_button(main_container)
	
	# Create shop UI (hidden initially)
	create_shop_ui()


func create_resource_display(parent: VBoxContainer):
	# Resource panel background - make it wider for more resources
	var resource_panel = Panel.new()
	resource_panel.custom_minimum_size = Vector2(140, 80)
	
	# Style the panel (same as before)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color.WHITE
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	resource_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Resource text
	resource_label = Label.new()
	resource_label.text = "Meals: 0/0 | Wood: 0/0"  # Updated initial text
	resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resource_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resource_label.add_theme_font_size_override("font_size", 12)  # Slightly smaller to fit more text
	resource_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Center the label in the panel
	resource_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resource_label.add_theme_constant_override("margin_left", 5)
	resource_label.add_theme_constant_override("margin_right", 5)
	
	resource_panel.add_child(resource_label)
	parent.add_child(resource_panel)

func create_zoom_controls(parent: VBoxContainer):
	# Zoom in button
	var zoom_in = Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(60, 40)
	zoom_in.add_theme_font_size_override("font_size", 20)
	zoom_in.pressed.connect(_on_zoom_in_pressed)
	parent.add_child(zoom_in)
	
	# Zoom out button
	var zoom_out = Button.new()
	zoom_out.text = "-"
	zoom_out.custom_minimum_size = Vector2(60, 40)
	zoom_out.add_theme_font_size_override("font_size", 20)
	zoom_out.pressed.connect(_on_zoom_out_pressed)
	parent.add_child(zoom_out)

func create_build_mode_button(parent: VBoxContainer):
	build_mode_button = Button.new()
	build_mode_button.text = "Build"
	build_mode_button.custom_minimum_size = Vector2(80, 50)
	build_mode_button.add_theme_font_size_override("font_size", 16)
	
	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.3, 0.6, 0.3)  # Green when not active
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	build_mode_button.add_theme_stylebox_override("normal", button_style)
	
	build_mode_button.pressed.connect(_on_build_mode_pressed)
	parent.add_child(build_mode_button)

func _on_zoom_in_pressed():
	zoom_in_pressed.emit()

func _on_zoom_out_pressed():
	zoom_out_pressed.emit()

func _on_build_mode_pressed():
	build_mode_toggled.emit()
	BuildModeManager.toggle_build_mode()

func _on_build_mode_changed(is_active: bool):
	if build_mode_button:
		if is_active:
			# Check what mode we're in
			if BuildModeManager.current_build_mode == BuildModeManager.BuildMode.PLACE_NEW:
				build_mode_button.text = "Placing..."
				var orange_style = StyleBoxFlat.new()
				orange_style.bg_color = Color(0.9, 0.5, 0.1)  # Orange for placing
				orange_style.corner_radius_top_left = 8
				orange_style.corner_radius_top_right = 8
				orange_style.corner_radius_bottom_left = 8
				orange_style.corner_radius_bottom_right = 8
				build_mode_button.add_theme_stylebox_override("normal", orange_style)
			else:
				build_mode_button.text = "Move Buildings"
				var red_style = StyleBoxFlat.new()
				red_style.bg_color = Color(0.8, 0.4, 0.2)  # Orange-red for moving
				red_style.corner_radius_top_left = 8
				red_style.corner_radius_top_right = 8
				red_style.corner_radius_bottom_left = 8
				red_style.corner_radius_bottom_right = 8
				build_mode_button.add_theme_stylebox_override("normal", red_style)
		else:
			build_mode_button.text = "Build"
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.3, 0.6, 0.3)  # Green when not active
			normal_style.corner_radius_top_left = 8
			normal_style.corner_radius_top_right = 8
			normal_style.corner_radius_bottom_left = 8
			normal_style.corner_radius_bottom_right = 8
			build_mode_button.add_theme_stylebox_override("normal", normal_style)
			
			# When build mode ends, refresh shop if it's open
			if building_shop_ui and building_shop_ui.visible:
				populate_shop()
				print("Shop refreshed after build mode ended")


func _on_build_mode_toggled_refresh_shop(is_active: bool):
	# When build mode ends, refresh the shop to show updated counts
	if not is_active and building_shop_ui and building_shop_ui.visible:
		populate_shop()
		
func find_kitchen():
	# Find the village scene and look for kitchen
	var village = get_tree().get_first_node_in_group("village")
	if not village:
		# Fallback - look in current scene
		village = get_tree().current_scene
	
	if village:
		for child in village.get_children():
			if child.has_method("is_kitchen"):
				return child
	return null

func find_wood_storage():
	# Find the village scene and look for wood storage
	var village = get_tree().get_first_node_in_group("village")
	if not village:
		# Fallback - look in current scene
		village = get_tree().current_scene
	
	if village:
		for child in village.get_children():
			if child.has_method("is_wood_storage"):
				return child
	return null

func create_shop_button(parent: VBoxContainer):
	shop_button = Button.new()
	shop_button.text = "Shop"
	shop_button.custom_minimum_size = Vector2(80, 50)
	shop_button.add_theme_font_size_override("font_size", 16)
	
	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.4, 0.8)  # Blue
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	shop_button.add_theme_stylebox_override("normal", button_style)
	
	shop_button.pressed.connect(_on_shop_button_pressed)
	parent.add_child(shop_button)

func _on_shop_button_pressed():
	print("Shop button pressed!")
	if building_shop_ui:
		print("Showing shop UI...")
		building_shop_ui.show()
		# Wait a frame then populate to ensure UI is ready
		await get_tree().process_frame
		populate_shop()
	else:
		print("ERROR: building_shop_ui is null!")
	shop_button_pressed.emit()
	
func create_shop_ui():
	print("Creating shop UI...")
	
	# Create shop UI as overlay
	building_shop_ui = Control.new()
	building_shop_ui.name = "BuildingShopUI"
	building_shop_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Semi-transparent background that consumes ALL input
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # This stops input from passing through
	building_shop_ui.add_child(bg)
	
	# Main panel
	var shop_panel = Panel.new()
	shop_panel.size = Vector2(600, 500)
	shop_panel.position = Vector2(276, 74)  # Center on screen
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.2)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color.WHITE
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	shop_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("margin_left", 20)
	main_vbox.add_theme_constant_override("margin_right", 20)
	main_vbox.add_theme_constant_override("margin_top", 20)
	main_vbox.add_theme_constant_override("margin_bottom", 20)
	main_vbox.add_theme_constant_override("separation", 10)
	
	# Title
	var title = Label.new()
	title.text = "Building Shop"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	# Player resources display - STORE DIRECT REFERENCE
	shop_resources_label = Label.new()
	shop_resources_label.add_theme_font_size_override("font_size", 14)
	shop_resources_label.add_theme_color_override("font_color", Color.YELLOW)
	shop_resources_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(shop_resources_label)
	print("Created shop_resources_label")
	
	# Scroll container for buildings
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	
	# STORE DIRECT REFERENCE to buildings container
	shop_buildings_vbox = VBoxContainer.new()
	shop_buildings_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(shop_buildings_vbox)
	main_vbox.add_child(scroll)
	print("Created shop_buildings_vbox")
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.pressed.connect(_on_shop_close_pressed)
	main_vbox.add_child(close_button)
	
	shop_panel.add_child(main_vbox)
	building_shop_ui.add_child(shop_panel)
	
	# ADDED: Make the whole shop UI consume input events
	building_shop_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	
	add_child(building_shop_ui)
	
	building_shop_ui.hide()  # Start hidden
	print("Shop UI created successfully with input blocking")

func populate_shop():
	print("=== POPULATE SHOP DEBUG ===")
	print("Building shop UI exists: ", building_shop_ui != null)
	print("Shop buildings vbox exists: ", shop_buildings_vbox != null)
	print("Shop resources label exists: ", shop_resources_label != null)
	
	if not building_shop_ui or not shop_buildings_vbox or not shop_resources_label:
		print("ERROR: Missing UI elements!")
		return
	
	# Clear existing buildings
	for child in shop_buildings_vbox.get_children():
		child.queue_free()
	
	# Check if BuildingShop exists
	print("BuildingShop exists: ", BuildingShop != null)
	if BuildingShop:
		print("Available buildings count: ", BuildingShop.available_buildings.size())
		
		# Update resources display
		shop_resources_label.text = BuildingShop.get_resources_text() + " | Level: " + str(BuildingShop.player_level)
		print("Resources text: ", shop_resources_label.text)
		
		# Add buildings
		if BuildingShop.available_buildings.size() > 0:
			for building_data in BuildingShop.available_buildings:
				print("Adding building: ", building_data.display_name)
				create_building_button(shop_buildings_vbox, building_data)
			print("All buildings added to shop")
		else:
			print("ERROR: No buildings in BuildingShop.available_buildings!")
			var test_label = Label.new()
			test_label.text = "No buildings found - check BuildingShop setup"
			test_label.add_theme_color_override("font_color", Color.RED)
			shop_buildings_vbox.add_child(test_label)
	else:
		print("ERROR: BuildingShop autoload not found!")
		var error_label = Label.new()
		error_label.text = "BuildingShop not found - check autoload settings"
		error_label.add_theme_color_override("font_color", Color.RED)
		shop_buildings_vbox.add_child(error_label)

func create_building_button(parent: VBoxContainer, building_data: BuildingData):
	var current_count = BuildingShop.get_building_count(building_data.building_type)
	var next_level_req = BuildingShop.get_next_level_requirement(building_data)
	var can_build_more = BuildingShop.can_build_more(building_data)
	
	print("Creating button for: ", building_data.display_name, " (Count: ", current_count, ", Next level: ", next_level_req, ")")
	
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 80)  # Slightly taller for more info
	
	# Building info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Building name with count
	var name_label = Label.new()
	if building_data.max_buildings == -1:
		name_label.text = "%s (Owned: %d)" % [building_data.display_name, current_count]
	else:
		name_label.text = "%s (Owned: %d/%d)" % [building_data.display_name, current_count, building_data.max_buildings]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_label)
	
	# Building description  
	var desc_label = Label.new()
	desc_label.text = building_data.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)
	
	# Cost and requirements
	var cost_label = Label.new()
	if can_build_more:
		var cost_text = "Next: " + building_data.get_cost_text() + " | Level: " + str(next_level_req)
		cost_label.text = cost_text
		cost_label.add_theme_color_override("font_color", Color.CYAN)
	else:
		cost_label.text = "Maximum built"
		cost_label.add_theme_color_override("font_color", Color.ORANGE)
	cost_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(cost_label)
	
	container.add_child(info_vbox)
	
	# Buy button
	var buy_button = Button.new()
	buy_button.custom_minimum_size = Vector2(100, 60)
	
	if not can_build_more:
		buy_button.text = "Max Built"
		buy_button.disabled = true
		buy_button.add_theme_color_override("font_color", Color.ORANGE)
	else:
		var can_purchase = BuildingShop.can_purchase_building(building_data)
		var level_requirement_met = BuildingShop.player_level >= next_level_req
		
		if not level_requirement_met:
			buy_button.text = "Level\n" + str(next_level_req)
			buy_button.disabled = true
			buy_button.add_theme_color_override("font_color", Color.GRAY)
		elif can_purchase:
			buy_button.text = "Buy\n#" + str(current_count + 1)
			buy_button.add_theme_color_override("font_color", Color.GREEN)
			buy_button.pressed.connect(_on_building_purchase.bind(building_data))
		else:
			buy_button.text = "Can't\nAfford"
			buy_button.disabled = true
			buy_button.add_theme_color_override("font_color", Color.RED)
	
	container.add_child(buy_button)
	parent.add_child(container)
	
	# Add separator line
	var separator = HSeparator.new()
	separator.add_theme_color_override("separator", Color.GRAY)
	parent.add_child(separator)
	
	print("Button created for: ", building_data.display_name, " - Can build more: ", can_build_more)
	
	
func _on_building_purchase(building_data: BuildingData):
	print("Attempting to purchase: ", building_data.display_name)
	if BuildingShop.purchase_building(building_data):
		# Close the shop so player can see the map for placement
		building_shop_ui.hide()
		
		print("Successfully purchased - now place the building on the map!")
		
		# ADDED: Consume any pending input events to prevent click-through
		get_viewport().set_input_as_handled()
		
		# Don't refresh shop yet - wait until placement is complete
	else:
		print("Purchase failed")


func _on_shop_close_pressed():
	building_shop_ui.hide()
	# Consume the input event to prevent click-through
	get_viewport().set_input_as_handled()

# Update the existing update_resource_display to also update shop if open
func update_resource_display():
	if resource_label:
		var kitchen = find_kitchen()
		var wood_storage = find_wood_storage()
		
		var meals = 0
		var max_meals = 0
		var wood = 0
		var max_wood = 0
		
		# Get meal counts
		if kitchen:
			meals = kitchen.stored_meals if kitchen.has_method("stored_meals") or "stored_meals" in kitchen else 0
			max_meals = kitchen.max_meals if kitchen.has_method("max_meals") or "max_meals" in kitchen else 0
			# Update building shop meals count
			BuildingShop.player_meals = meals
		
		# Get wood counts
		if wood_storage:
			wood = wood_storage.stored_wood if wood_storage.has_method("stored_wood") or "stored_wood" in wood_storage else 0
			max_wood = wood_storage.max_wood if wood_storage.has_method("max_wood") or "max_wood" in wood_storage else 0
			# Update building shop wood count (you'll need to add this to BuildingShop)
			BuildingShop.player_wood = wood
		
		# Update the display to show both resources
		resource_label.text = "Meals: %d/%d\nWood: %d/%d" % [meals, max_meals, wood, max_wood]
	
	# Update shop display if it's open
	if building_shop_ui and building_shop_ui.visible:
		populate_shop()


func _input(event):
	# If shop is open, consume scroll events to prevent camera zoom
	if building_shop_ui and building_shop_ui.visible:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Let the scroll container handle it, but don't let it pass through to camera
				get_viewport().set_input_as_handled()

# BuildingUI.gd - Fixed version
extends Control
class_name BuildingUI

var current_building: BuildableBuilding
var main_panel: Panel
var content_container: VBoxContainer

func _init():
	name = "BuildingUI"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Semi-transparent background that blocks input
	var bg_color_rect = ColorRect.new()
	bg_color_rect.color = Color(0, 0, 0, 0.5)
	bg_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks underneath
	add_child(bg_color_rect)
	
	# Close UI when clicking background
	bg_color_rect.gui_input.connect(_on_background_clicked)
	
	setup_main_panel()

func _on_background_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Only close if clicking outside the main panel
		var panel_rect = Rect2(main_panel.global_position, main_panel.size)
		if not panel_rect.has_point(event.global_position):
			close_ui()

func setup_main_panel():
	main_panel = Panel.new()
	main_panel.size = Vector2(450, 500)  # Made taller
	main_panel.position = Vector2(350, 100)  # Moved away from edge
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color.LIGHT_SALMON
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color.BLACK
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# ScrollContainer to handle overflow
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.add_theme_constant_override("margin_left", 10)
	scroll_container.add_theme_constant_override("margin_right", 10)
	scroll_container.add_theme_constant_override("margin_top", 10)
	scroll_container.add_theme_constant_override("margin_bottom", 10)
	
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 10)
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	scroll_container.add_child(content_container)
	main_panel.add_child(scroll_container)
	add_child(main_panel)

func show_building_ui(building: BuildableBuilding):
	current_building = building
	clear_content()
	
	# Building title
	var title_label = Label.new()
	title_label.text = building.building_name
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color.BLACK)
	content_container.add_child(title_label)
	
	# Building info (status, level, etc.)
	add_building_info()
	
	# Add separator
	add_separator()
	
	# Add upgrade section if building supports upgrades
	if building.has_method("can_upgrade"):
		add_upgrade_section()
		add_separator()
	
	# Add job assignment if building has a job
	if building.has_meta("job"):
		add_job_assignment_section()
		add_separator()
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.pressed.connect(close_ui)
	content_container.add_child(close_button)
	
	show()

func clear_content():
	for child in content_container.get_children():
		child.queue_free()
	await get_tree().process_frame  # Wait for cleanup

func add_separator():
	var separator = HSeparator.new()
	separator.add_theme_color_override("separator", Color.GRAY)
	content_container.add_child(separator)

func add_building_info():
	var info_label = Label.new()
	var info_text = ""
	
	# Add building level if available (safer check)
	if "building_level" in current_building:
		info_text += "Level: " + str(current_building.building_level) + "\n"
	
	# Add storage status if available
	if current_building.has_method("get_storage_status"):
		info_text += current_building.get_storage_status() + "\n"
	
	# Add building size info
	if "building_size" in current_building:
		info_text += "Size: " + str(current_building.building_size.x) + "x" + str(current_building.building_size.y) + "\n"
	
	if info_text != "":
		info_label.text = info_text.strip_edges()
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.add_theme_color_override("font_color", Color.DARK_BLUE)
		content_container.add_child(info_label)

func add_upgrade_section():
	if not current_building.has_method("can_upgrade"):
		return
	
	# Section title
	var upgrade_title = Label.new()
	upgrade_title.text = "Building Upgrade"
	upgrade_title.add_theme_font_size_override("font_size", 18)
	upgrade_title.add_theme_color_override("font_color", Color.BLACK)
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(upgrade_title)
	
	
	
	if current_building.is_upgrading:
		# Show upgrade progress
		var progress_label = Label.new()
		if current_building.has_method("get_upgrade_info"):
			progress_label.text = current_building.get_upgrade_info()
		else:
			progress_label.text = "Upgrading in progress..."
		progress_label.add_theme_color_override("font_color", Color.ORANGE)
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_container.add_child(progress_label)
	elif current_building.can_upgrade():
		var upgrade_cost = current_building.get_upgrade_cost()
		print("DEBUG: Upgrade cost: ", upgrade_cost)
		
		if not upgrade_cost.is_empty():
			# Show what the upgrade will give
			var benefit_label = Label.new()
			var next_level = current_building.building_level + 1
			if next_level == 2:
				benefit_label.text = "Upgrade to Level 2: Capacity 2500 gold"
			elif next_level == 3:
				benefit_label.text = "Upgrade to Level 3: Capacity 5000 gold"
			else:
				benefit_label.text = "Upgrade to Level " + str(next_level)
			benefit_label.add_theme_color_override("font_color", Color.DARK_GREEN)
			benefit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content_container.add_child(benefit_label)
			
			# Show upgrade cost
			var cost_label = Label.new()
			var cost_parts = []
			if upgrade_cost.get("cost_gold", 0) > 0:
				cost_parts.append(str(upgrade_cost.cost_gold) + " gold")
			if upgrade_cost.get("cost_wood", 0) > 0:
				cost_parts.append(str(upgrade_cost.cost_wood) + " wood")  
			if upgrade_cost.get("cost_stone", 0) > 0:
				cost_parts.append(str(upgrade_cost.cost_stone) + " stone")
			
			cost_label.text = "Cost: " + ", ".join(cost_parts)
			cost_label.add_theme_color_override("font_color", Color.DARK_RED)
			cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content_container.add_child(cost_label)
			
			# Check if we can afford it
			var can_afford = check_can_afford_upgrade(upgrade_cost)
			
			# Upgrade button
			var upgrade_button = Button.new()
			upgrade_button.text = "Start Upgrade"
			upgrade_button.custom_minimum_size = Vector2(150, 40)
			if can_afford:
				upgrade_button.add_theme_color_override("font_color", Color.GREEN)
				upgrade_button.pressed.connect(start_upgrade)
			else:
				upgrade_button.text = "Cannot Afford"
				upgrade_button.disabled = true
				upgrade_button.add_theme_color_override("font_color", Color.RED)
			content_container.add_child(upgrade_button)
	else:
		var status_label = Label.new()
		if current_building.building_level >= 3:
			status_label.text = "Maximum Level Reached"
		else:
			status_label.text = "Cannot upgrade right now"
		status_label.add_theme_color_override("font_color", Color.GRAY)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_container.add_child(status_label)

func check_can_afford_upgrade(upgrade_cost: Dictionary) -> bool:
	var gold_storage = current_building  # Assuming we're upgrading gold storage
	var wood_storage = find_wood_storage()
	var stone_storage = find_stone_storage()
	
	var has_gold = gold_storage.stored_gold >= upgrade_cost.get("cost_gold", 0)
	var has_wood = wood_storage != null and wood_storage.stored_wood >= upgrade_cost.get("cost_wood", 0)
	var has_stone = stone_storage != null and stone_storage.stored_stone >= upgrade_cost.get("cost_stone", 0)
	
	return has_gold and has_wood and has_stone

func find_wood_storage():
	var wood_storages = get_tree().get_nodes_in_group("wood_storage")
	return wood_storages[0] if wood_storages.size() > 0 else null

func find_stone_storage():
	var stone_storages = get_tree().get_nodes_in_group("stone_storage")
	return stone_storages[0] if stone_storages.size() > 0 else null

func add_job_assignment_section():
	var job = current_building.get_meta("job") as Job
	if not job:
		return
	
	# Section title
	var job_title = Label.new()
	var job_name = get_job_display_name(job.job_type)
	job_title.text = "Job Assignment: " + job_name
	job_title.add_theme_font_size_override("font_size", 18)
	job_title.add_theme_color_override("font_color", Color.BLACK)
	job_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(job_title)
	
	# Current worker
	var current_worker_label = Label.new()
	if job.assigned_villager:
		current_worker_label.text = "Current Worker: " + job.assigned_villager.villager_name
		current_worker_label.add_theme_color_override("font_color", Color.BLUE)
	else:
		current_worker_label.text = "Current Worker: None"
		current_worker_label.add_theme_color_override("font_color", Color.BLUE)
	current_worker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(current_worker_label)
	
	# Available villagers
	var available_villagers = get_available_villagers_for_job(job)
	
	if not available_villagers.is_empty():
		for villager in available_villagers:
			if villager == job.assigned_villager:
				continue  # Skip current worker
			
			var assign_button = Button.new()
			assign_button.text = "Assign " + villager.villager_name
			assign_button.custom_minimum_size = Vector2(200, 30)
			assign_button.pressed.connect(func(): assign_villager_to_job(villager, job))
			content_container.add_child(assign_button)
	
	# Unassign button if someone is assigned
	if job.assigned_villager:
		var unassign_button = Button.new()
		unassign_button.text = "Unassign Worker"
		unassign_button.custom_minimum_size = Vector2(150, 30)
		unassign_button.add_theme_color_override("font_color", Color.RED)
		unassign_button.pressed.connect(func(): unassign_worker(job))
		content_container.add_child(unassign_button)

func get_job_display_name(job_type: Job.JobType) -> String:
	match job_type:
		Job.JobType.FARM_WORKER: return "Farm Worker"
		Job.JobType.WOOD_GATHERER: return "Wood Gatherer"
		Job.JobType.STONE_GATHERER: return "Stone Gatherer"
		Job.JobType.BUILDER: return "Builder"
		_: return "Unknown Job"

func get_available_villagers_for_job(job: Job) -> Array[Villager]:
	var available: Array[Villager] = []
	var villagers = get_tree().get_nodes_in_group("villagers")
	
	for villager in villagers:
		if not villager.assigned_job or villager == job.assigned_villager:
			available.append(villager)
	
	return available

func assign_villager_to_job(villager: Villager, job: Job):
	JobManager.assign_villager_to_job(villager, job)
	# Refresh the UI
	show_building_ui(current_building)

func unassign_worker(job: Job):
	if job.assigned_villager:
		JobManager.unassign_villager_from_job(job.assigned_villager)
	# Refresh the UI
	show_building_ui(current_building)

func start_upgrade():
	if current_building.has_method("start_upgrade"):
		if current_building.start_upgrade():
			print("Upgrade started for ", current_building.building_name)
			# Refresh the UI to show upgrade progress
			show_building_ui(current_building)
		else:
			print("Failed to start upgrade - insufficient resources")

func close_ui():
	queue_free()

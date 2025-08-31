# JobManager.gd - Create UI entirely in code
extends Node

var all_villagers: Array[Villager] = []
var all_jobs: Array[Job] = []
var job_assignment_ui: Control
var ui_canvas_layer: CanvasLayer

func _ready():
	print("JobManager: Creating UI in code...")
	
	# Create CanvasLayer for UI
	ui_canvas_layer = CanvasLayer.new()
	ui_canvas_layer.name = "JobUI_Layer"
	ui_canvas_layer.layer = 100
	get_tree().root.add_child.call_deferred(ui_canvas_layer)
	
	# Create the UI entirely in code
	create_job_ui()
	
	print("JobManager: UI created in code")

func create_job_ui():
	# Root Control
	job_assignment_ui = Control.new()
	job_assignment_ui.name = "JobAssignmentUI"
	job_assignment_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Semi-transparent background
	var bg_color_rect = ColorRect.new()
	bg_color_rect.color = Color(0, 0, 0, 0.5)
	bg_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	job_assignment_ui.add_child(bg_color_rect)
	
	# Main panel
	var panel = Panel.new()
	panel.name = "MainPanel"
	panel.size = Vector2(400, 300)
	panel.position = Vector2(200, 150)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color.WHITE
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color.BLACK
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# VBoxContainer
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	# Job title label
	var job_label = Label.new()
	job_label.name = "JobLabel"
	job_label.text = "Job Assignment"
	job_label.add_theme_font_size_override("font_size", 20)
	job_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Current worker label
	var current_label = Label.new()
	current_label.name = "CurrentLabel"
	current_label.text = "Current: None"
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Villager list
	var villager_list = VBoxContainer.new()
	villager_list.name = "VillagerList"
	
	# Close button
	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	
	# Assemble the UI
	vbox.add_child(job_label)
	vbox.add_child(current_label)
	vbox.add_child(villager_list)
	vbox.add_child(close_button)
	panel.add_child(vbox)
	job_assignment_ui.add_child(panel)
	ui_canvas_layer.add_child(job_assignment_ui)
	
	# Start hidden
	job_assignment_ui.hide()
	
	print("UI created with panel at: ", panel.position, " size: ", panel.size)

func register_villager(villager: Villager):
	if villager not in all_villagers:
		all_villagers.append(villager)
		print("Registered villager: ", villager.villager_name)

func register_job(job: Job):
	if job not in all_jobs:
		all_jobs.append(job)
		print("Registered job: ", job.job_type)

# Replace just this function in JobManager.gd
func show_job_assignment_ui(job: Job):
	print("JobManager: Creating simple UI like test panel...")
	
	# Remove any existing UI first
	var existing = get_tree().root.get_node_or_null("SimpleJobUI")
	if existing:
		existing.queue_free()
	
	# Create UI EXACTLY like your working test
	var test_control = Control.new()
	test_control.name = "SimpleJobUI"
	test_control.size = Vector2(1152, 648)
	test_control.position = Vector2.ZERO
	
	var test_panel = Panel.new()
	test_panel.size = Vector2(400, 300)
	test_panel.position = Vector2(200, 200)
	
	# Bright color so we can definitely see it
	var style = StyleBoxFlat.new()
	style.bg_color = Color.BLUE  # Different color than your test
	test_panel.add_theme_stylebox_override("panel", style)
	
	# Job title
	var job_name = ""
	match job.job_type:
		Job.JobType.FARM_WORKER:
			job_name = "Farm Worker"
		Job.JobType.KITCHEN_WORKER:
			job_name = "Kitchen Worker"
		_:
			job_name = "Unknown Job"
	
	var title_label = Label.new()
	title_label.text = "Assign " + job_name
	title_label.position = Vector2(20, 20)
	title_label.size = Vector2(360, 30)
	title_label.add_theme_font_size_override("font_size", 18)
	
	# Current worker
	var current_label = Label.new()
	if job.assigned_villager:
		current_label.text = "Current: " + job.assigned_villager.villager_name
	else:
		current_label.text = "Current: None"
	current_label.position = Vector2(20, 60)
	current_label.size = Vector2(360, 30)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(150, 250)
	close_btn.size = Vector2(100, 30)
	close_btn.pressed.connect(func(): test_control.queue_free())
	
	# Add villager buttons
	var y_pos = 100
	for villager in all_villagers:
		if not villager.assigned_job:
			var btn = Button.new()
			btn.text = "Assign " + villager.villager_name
			btn.position = Vector2(20, y_pos)
			btn.size = Vector2(200, 30)
			btn.pressed.connect(func(): 
				if villager.assigned_job:
					villager.unassign_job()
				villager.assign_job(job)
				test_control.queue_free()
				print("Assigned ", villager.villager_name, " to job")
			)
			test_panel.add_child(btn)
			y_pos += 40
	
	# If current job has a worker, add unassign button
	if job.assigned_villager:
		var unassign_btn = Button.new()
		unassign_btn.text = "Unassign Current"
		unassign_btn.position = Vector2(240, 100)
		unassign_btn.size = Vector2(140, 30)
		unassign_btn.pressed.connect(func():
			job.assigned_villager.unassign_job()
			test_control.queue_free()
			print("Unassigned worker")
		)
		test_panel.add_child(unassign_btn)
	
	# Assemble exactly like your working test
	test_panel.add_child(title_label)
	test_panel.add_child(current_label)
	test_panel.add_child(close_btn)
	test_control.add_child(test_panel)
	get_tree().root.add_child(test_control)
	
	print("Simple UI created - should be BLUE panel")

func _on_assign_villager(villager: Villager, job: Job):
	print("Assigning ", villager.villager_name, " to job")
	if villager.assigned_job:
		villager.unassign_job()
	villager.assign_job(job)
	job_assignment_ui.hide()

func _on_unassign_pressed(job: Job):
	print("Unassigning worker from job")
	if job.assigned_villager:
		job.assigned_villager.unassign_job()
	job_assignment_ui.hide()

func _on_close_pressed():
	print("Closing UI")
	job_assignment_ui.hide()

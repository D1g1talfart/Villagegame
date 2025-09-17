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

func show_job_assignment_ui(job: Job):
	print("JobManager: Creating job assignment UI for job type: ", job.job_type)
	
	# Remove any existing UI first
	var existing = get_tree().root.get_node_or_null("SimpleJobUI")
	if existing:
		existing.queue_free()
	
	# Create UI 
	var test_control = Control.new()
	test_control.name = "SimpleJobUI"
	test_control.size = Vector2(1152, 648)
	test_control.position = Vector2.ZERO
	
	var test_panel = Panel.new()
	test_panel.size = Vector2(400, 350)
	test_panel.position = Vector2(200, 200)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color.BLUE
	test_panel.add_theme_stylebox_override("panel", style)
	
	# Job title
	var job_name = ""
	match job.job_type:
		Job.JobType.FARM_WORKER:
			job_name = "Farm Worker"
		Job.JobType.WOOD_GATHERER:
			job_name = "Wood Gatherer"
		Job.JobType.STONE_GATHERER:
			job_name = "Stone Gatherer"
		Job.JobType.BUILDER:
			job_name = "Builder (Upgrading " + job.workplace.building_name + ")"
		_:
			job_name = "Unknown Job"
	
	var title_label = Label.new()
	title_label.text = "Assign " + job_name
	title_label.position = Vector2(20, 20)
	title_label.size = Vector2(360, 30)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Current worker
	var current_label = Label.new()
	if job.assigned_villager:
		current_label.text = "Current Worker: " + job.assigned_villager.villager_name
		current_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		current_label.text = "Current Worker: None"
		current_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	current_label.position = Vector2(20, 60)
	current_label.size = Vector2(360, 30)
	current_label.add_theme_font_size_override("font_size", 14)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(150, 300)
	close_btn.size = Vector2(100, 30)
	close_btn.pressed.connect(func(): test_control.queue_free())
	
	# Add available villagers
	var y_pos = 100
	var available_villagers = get_available_villagers_for_job(job)
	
	if available_villagers.is_empty():
		var no_villagers_label = Label.new()
		no_villagers_label.text = "No available villagers"
		no_villagers_label.position = Vector2(20, y_pos)
		no_villagers_label.size = Vector2(360, 30)
		no_villagers_label.add_theme_color_override("font_color", Color.GRAY)
		test_panel.add_child(no_villagers_label)
	else:
		for villager in available_villagers:
			var btn = Button.new()
			if villager == job.assigned_villager:
				btn.text = villager.villager_name + " (Current)"
				btn.add_theme_color_override("font_color", Color.YELLOW)
			else:
				btn.text = "Assign " + villager.villager_name
				btn.add_theme_color_override("font_color", Color.GREEN)
			
			btn.position = Vector2(20, y_pos)
			btn.size = Vector2(200, 30)
			btn.pressed.connect(func(): 
				assign_villager_to_job(villager, job)
				test_control.queue_free()
			)
			test_panel.add_child(btn)
			y_pos += 35
	
	# If current job has a worker, add unassign button
	if job.assigned_villager:
		var unassign_btn = Button.new()
		unassign_btn.text = "Unassign Current"
		unassign_btn.position = Vector2(240, 100)
		unassign_btn.size = Vector2(140, 30)
		unassign_btn.add_theme_color_override("font_color", Color.RED)
		unassign_btn.pressed.connect(func():
			unassign_villager_from_job(job.assigned_villager)
			test_control.queue_free()
		)
		test_panel.add_child(unassign_btn)
	
	# Assemble UI
	test_panel.add_child(title_label)
	test_panel.add_child(current_label)
	test_panel.add_child(close_btn)
	test_control.add_child(test_panel)
	get_tree().root.add_child(test_control)
	
	print("Job assignment UI created")

func get_available_villagers_for_job(job: Job) -> Array[Villager]:
	var available: Array[Villager] = []
	
	for villager in all_villagers:
		# Include villagers with no job OR the current worker of this job
		if not villager.assigned_job or villager == job.assigned_villager:
			available.append(villager)
	
	print("Available villagers for job: ", available.size())
	for v in available:
		var status = "No Job" if not v.assigned_job else "Current Worker"
		print("  - ", v.villager_name, " (", status, ")")
	
	return available

func assign_villager_to_job(villager: Villager, job: Job):
	print("=== JOB ASSIGNMENT ===")
	print("Assigning ", villager.villager_name, " to ", job.job_type)
	
	# If someone else is already working this job, unassign them first
	if job.assigned_villager and job.assigned_villager != villager:
		print("Unassigning current worker: ", job.assigned_villager.villager_name)
		unassign_villager_from_job(job.assigned_villager)
	
	# If this villager has another job, unassign them from it
	if villager.assigned_job and villager.assigned_job != job:
		print("Unassigning ", villager.villager_name, " from previous job")
		unassign_villager_from_job(villager)
	
	# Assign the villager to the job
	villager.assign_job(job)
	print("Assignment complete: ", villager.villager_name, " -> ", job.job_type)

func unassign_villager_from_job(villager: Villager):
	print("Unassigning ", villager.villager_name, " from their job")
	villager.unassign_job()
	print("Unassignment complete")

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
	
# Helper function to get jobs by type
func get_jobs_by_type(job_type: Job.JobType) -> Array[Job]:
	var jobs_of_type: Array[Job] = []
	for job in all_jobs:
		if job.job_type == job_type:
			jobs_of_type.append(job)
	return jobs_of_type

# Helper function to unregister a job
func unregister_job(job: Job):
	if job in all_jobs:
		all_jobs.erase(job)
		print("Unregistered job: ", job.job_type)

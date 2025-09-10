# JobAssignmentUI.gd - Manual node finding approach
extends Control
class_name JobAssignmentUI

signal villager_assigned(villager: Villager, job: Job)
signal ui_closed

var panel: Panel
var job_label: Label
var villager_list: VBoxContainer
var close_button: Button
var current_worker_label: Label

var current_job: Job
var available_villagers: Array[Villager] = []

func _ready():
	print("JobAssignmentUI _ready called")
	# Wait a frame to ensure the scene is fully loaded
	call_deferred("setup_nodes")

func setup_nodes():
	print("Setting up nodes...")
	
	# Find all nodes manually
	panel = find_child("Panel") as Panel
	print("Panel found: ", panel != null)
	
	if panel:
		var vbox = panel.find_child("VBoxContainer") as VBoxContainer
		print("VBoxContainer found: ", vbox != null)
		
		if vbox:
			job_label = vbox.find_child("JobLabel") as Label
			current_worker_label = vbox.find_child("CurrentWorkerLabel") as Label
			villager_list = vbox.find_child("VillagerList") as VBoxContainer
			close_button = vbox.find_child("CloseButton") as Button
			
			print("JobLabel found: ", job_label != null)
			print("CurrentWorkerLabel found: ", current_worker_label != null)
			print("VillagerList found: ", villager_list != null)
			print("CloseButton found: ", close_button != null)
			
			if close_button:
				close_button.pressed.connect(_on_close_pressed)
			else:
				print("ERROR: CloseButton is null!")
		else:
			print("ERROR: VBoxContainer not found!")
	else:
		print("ERROR: Panel not found!")
	
	hide()  # Start hidden
	print("JobAssignmentUI setup complete")

func show_job_assignment(job: Job, villagers: Array[Villager]):
	print("show_job_assignment called with job type: ", job.job_type)
	
	# Double-check that our nodes are ready
	if not job_label:
		print("ERROR: job_label is still null! Re-finding nodes...")
		setup_nodes()
		if not job_label:
			print("CRITICAL ERROR: Cannot find JobLabel node!")
			return
	
	current_job = job
	available_villagers = villagers
	setup_ui()
	show()

# Replace the setup_ui() function with this simpler version
# Update setup_ui() in JobAssignmentUI.gd (with tabs)
func setup_ui():
	print("setup_ui called")
	
	if not current_job:
		print("ERROR: No current job")
		return
	
	if not job_label:
		print("ERROR: job_label is null in setup_ui!")
		return
	
	# Set job title
	var job_name = ""
	match current_job.job_type:
		Job.JobType.FARM_WORKER:
			job_name = "Farm Worker"
		Job.JobType.KITCHEN_WORKER:
			job_name = "Kitchen Worker"
		Job.JobType.WOOD_GATHERER:
			job_name = "Wood Cutter"
		_:
			job_name = "Unknown Job"
	
	print("Setting job_label text to: Assign " + job_name)
	job_label.text = "Assign " + job_name
	
	# Show current worker
	if current_worker_label:
		if current_job.assigned_villager:
			current_worker_label.text = "Current: " + current_job.assigned_villager.villager_name
		else:
			current_worker_label.text = "Current: None"
	
	if not villager_list:
		print("ERROR: villager_list is null!")
		return
	
	# Clear previous buttons
	for child in villager_list.get_children():
		child.queue_free()
	
	# Add unassign button if needed
	if current_job.assigned_villager:
		var unassign_button = Button.new()
		unassign_button.text = "Unassign Current Worker"
		unassign_button.pressed.connect(_on_unassign_pressed)
		villager_list.add_child(unassign_button)
	
	# Add available villagers
	for villager in available_villagers:
		if not villager.assigned_job:
			var button = Button.new()
			button.text = villager.villager_name
			button.pressed.connect(_on_villager_selected.bind(villager))
			villager_list.add_child(button)
	
	print("UI setup complete")
	
	# Force the Control to fill the viewport and add semi-transparent background
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add a semi-transparent background to the whole Control
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.5)  # Semi-transparent black
	add_theme_stylebox_override("panel", bg_style)
	
	# Make the main panel very visible
	if panel:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		panel.size = Vector2(400, 300)
		panel.position.x = 50  # Offset from left edge
		
		# Bright, opaque panel background
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color.WHITE
		panel_style.border_width_left = 3
		panel_style.border_width_right = 3
		panel_style.border_width_top = 3
		panel_style.border_width_bottom = 3
		panel_style.border_color = Color.BLACK
		panel.add_theme_stylebox_override("panel", panel_style)
		
		print("Panel configured - Size: ", panel.size, " Position: ", panel.position)
	
	print("UI should now be visible with semi-transparent background")

func _on_villager_selected(villager: Villager):
	villager_assigned.emit(villager, current_job)
	hide()

func _on_unassign_pressed():
	villager_assigned.emit(null, current_job)
	hide()

func _on_close_pressed():
	ui_closed.emit()
	hide()

# Farm.gd - Simplified unlimited resources
extends BuildableBuilding

var work_positions: Array[Vector3] = []

func _ready():
	building_name = "Farm"
	building_size = Vector2i(2, 2)
	super._ready()
	
	setup_work_positions()
	
	# Register farm job and set meta
	var farm_job = Job.new(Job.JobType.FARM_WORKER, self)
	JobManager.register_job(farm_job)
	set_meta("job", farm_job)
	print("Farm job registered - UNLIMITED RESOURCES")

func setup_work_positions():
	var center = Vector3.ZERO
	work_positions = [
		center + Vector3(1.5, 0, 0),    # Right side
		center + Vector3(-1.5, 0, 0),   # Left side
		center + Vector3(0, 0, 1.5),    # Front
		center + Vector3(0, 0, -1.5)    # Back
	]

func get_work_position() -> Vector3:
	if work_positions.is_empty():
		return global_position
	return global_position + work_positions[0]

func can_harvest() -> bool:
	# Always true - unlimited resources!
	return true

func harvest_crop() -> bool:
	# Always successful - the time limitation comes from villager work_duration
	print("Harvested crop from unlimited farm!")
	return true

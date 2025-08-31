# Create Job.gd
extends RefCounted
class_name Job

enum JobType { IDLE, FARM_WORKER, KITCHEN_WORKER }

var job_type: JobType
var workplace: Node3D
var assigned_villager: Villager

func _init(type: JobType, work_location: Node3D = null):
	job_type = type
	workplace = work_location

func can_assign_villager() -> bool:
	return assigned_villager == null

func assign_villager(villager: Villager) -> bool:
	if can_assign_villager():
		assigned_villager = villager
		return true
	return false

func unassign_villager():
	assigned_villager = null

# Override in subclasses
func get_work_position() -> Vector3:
	if workplace:
		return workplace.global_position
	return Vector3.ZERO

func should_work() -> bool:
	return true  # Override in subclasses

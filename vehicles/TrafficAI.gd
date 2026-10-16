extends Node
# Drives a TrafficCar around a loop of Marker3D waypoints.
# Attach as a sibling script on the TrafficCar node (next to VehicleController.gd).

@export var waypoints_path: NodePath
@export var arrival_distance: float = 6.0
@export var cruise_throttle: float = 0.5
@export var steer_gain: float = 1.5

var _waypoints: Array[Node3D] = []
var _current_index: int = 0
var _car: Node = null


func _ready() -> void:
	_car = get_parent()
	var route: Node = get_node_or_null(waypoints_path)
	if route == null:
		push_warning("TrafficAI: waypoints_path not set or not found")
		return
	for child in route.get_children():
		if child is Node3D:
			_waypoints.append(child as Node3D)


func _physics_process(_delta: float) -> void:
	if _waypoints.is_empty():
		return

	var target: Node3D = _waypoints[_current_index]
	var to_target: Vector3 = target.global_position - _car.global_position
	to_target.y = 0.0

	if to_target.length() < arrival_distance:
		_current_index = (_current_index + 1) % _waypoints.size()
		return

	var local_dir: Vector3 = _car.global_transform.basis.inverse() * to_target.normalized()
	var steer: float = clampf(local_dir.x * steer_gain, -1.0, 1.0)

	_car.call("set_throttle", cruise_throttle)
	_car.call("set_steer", steer)

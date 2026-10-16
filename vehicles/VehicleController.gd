extends RigidBody3D

@export var suspension_rest_length: float = 0.6
@export var suspension_stiffness: float = 18000.0
@export var suspension_damping: float = 2200.0
@export var tire_grip: float = 12.0
@export var engine_power: float = 3500.0
@export var brake_power: float = 6000.0
@export var max_steer_degrees: float = 32.0
@export var steer_speed: float = 3.0

var throttle_input: float = 0.0  # -1 reverse, 0 idle, 1 forward
var steer_input: float = 0.0     # -1 left, 1 right
var handbrake: bool = false

var _current_steer: float = 0.0
var _wheels: Array[RayCast3D] = []
var _front_wheels: Array[RayCast3D] = []


func _ready() -> void:
	_wheels = [
		get_node("Wheel_FL"), get_node("Wheel_FR"),
		get_node("Wheel_RL"), get_node("Wheel_RR"),
	]
	_front_wheels = [get_node("Wheel_FL"), get_node("Wheel_FR")]


# ---------- Called by touch UI ----------

func set_throttle(value: float) -> void:
	throttle_input = value


func set_steer(value: float) -> void:
	steer_input = value


func set_handbrake(value: bool) -> void:
	handbrake = value


# ---------- Physics ----------

func _physics_process(delta: float) -> void:
	_current_steer = move_toward(_current_steer, steer_input, steer_speed * delta)
	for wheel: RayCast3D in _front_wheels:
		wheel.rotation.y = -deg_to_rad(max_steer_degrees) * _current_steer

	for wheel: RayCast3D in _wheels:
		_apply_wheel_forces(wheel, delta)


func _apply_wheel_forces(wheel: RayCast3D, _delta: float) -> void:
	wheel.force_raycast_update()
	if not wheel.is_colliding():
		return

	var hit_point: Vector3 = wheel.get_collision_point()
	var wheel_world_pos: Vector3 = wheel.global_position
	var compression: float = suspension_rest_length - wheel_world_pos.distance_to(hit_point)
	if compression < 0.0:
		return

	var up: Vector3 = global_transform.basis.y
	var spring_force: float = compression * suspension_stiffness
	var point_velocity: Vector3 = linear_velocity + angular_velocity.cross(wheel_world_pos - global_position)
	var damping_force: float = -point_velocity.dot(up) * suspension_damping
	var suspension_total: float = spring_force + damping_force
	apply_force(up * suspension_total, wheel_world_pos - global_position)

	var right: Vector3 = wheel.global_transform.basis.x
	var lateral_speed: float = point_velocity.dot(right)
	var grip_force: Vector3 = -right * lateral_speed * tire_grip * mass * 0.1
	apply_force(grip_force, wheel_world_pos - global_position)

	var forward: Vector3 = -wheel.global_transform.basis.z
	if handbrake:
		var brake_force: float = -point_velocity.dot(forward) * brake_power * 0.1
		apply_force(forward * brake_force, wheel_world_pos - global_position)
	elif absf(throttle_input) > 0.01:
		apply_force(forward * throttle_input * engine_power, wheel_world_pos - global_position)

func stop_driving() -> void:
	throttle_input = 0.0
	steer_input = 0.0
	handbrake = false

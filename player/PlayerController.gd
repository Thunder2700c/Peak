extends CharacterBody3D

signal interact_target_changed(has_target: bool)
signal health_changed(current: float, maximum: float)
signal died

@export var walk_speed: float = 5.0
@export var acceleration: float = 12.0
@export var friction: float = 10.0
@export var gravity: float = 20.0
@export var max_slope_degrees: float = 55.0
@export var look_sensitivity: float = 0.004
@export var max_look_angle_degrees: float = 85.0
@export var invert_look_x: bool = false
@export var invert_look_y: bool = false
@export var interact_distance: float = 3.0
@export var interact_grace_time: float = 0.2
@export var debug_interact: bool = false
@export var player_health: float = 100.0
@export var fall_kill_height: float = -40.0

var is_dead: bool = false

var _current_target: Node = null
var _lost_target_time: float = 0.0
var _step_distance: float = 0.0
var _last_health: float = 100.0

@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRayCast
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var weapon_manager: Node3D = $Head/Camera3D/WeaponManager
@onready var health: Node = $HealthComponent
@onready var footstep_sound: AudioStreamPlayer = get_node_or_null("FootstepSound") as AudioStreamPlayer
@onready var hurt_sound: AudioStreamPlayer = get_node_or_null("HurtSound") as AudioStreamPlayer


func _ready() -> void:
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(max_slope_degrees)
	add_to_group("player")

	interaction_ray.enabled = true
	interaction_ray.position = Vector3.ZERO
	interaction_ray.rotation = Vector3.ZERO
	interaction_ray.target_position = Vector3(0.0, 0.0, -interact_distance)
	interaction_ray.collide_with_bodies = true
	interaction_ray.collide_with_areas = true
	interaction_ray.collision_mask = 1
	interaction_ray.add_exception(self)

	_last_health = player_health
	health.set("max_health", player_health)
	health.set("current_health", player_health)
	health.connect("health_changed", Callable(self, "_on_health_changed"))
	health.connect("on_death", Callable(self, "_on_death"))


func _on_health_changed(current: float, maximum: float) -> void:
	if current < _last_health and hurt_sound != null:
		hurt_sound.play()
	_last_health = current
	health_changed.emit(current, maximum)


func _on_death() -> void:
	is_dead = true
	died.emit()


func apply_look(relative: Vector2) -> void:
	if is_dead:
		return
	var x_dir: float = -1.0 if invert_look_x else 1.0
	var y_dir: float = -1.0 if invert_look_y else 1.0
	rotate_y(-relative.x * look_sensitivity * x_dir)
	var pitch: float = head.rotation.x - relative.y * look_sensitivity * y_dir
	var limit: float = deg_to_rad(max_look_angle_degrees)
	head.rotation.x = clampf(pitch, -limit, limit)


func toggle_flashlight() -> void:
	flashlight.call("toggle")


func fire_weapon() -> void:
	if is_dead:
		return
	weapon_manager.call("fire")


func try_interact() -> void:
	if is_dead:
		return
	if _current_target != null and is_instance_valid(_current_target):
		if _current_target.has_method("interact"):
			_current_target.call("interact")


func _update_interaction_target(delta: float) -> void:
	var found: Node = null
	if interaction_ray.is_colliding():
		var collider: Node = interaction_ray.get_collider() as Node
		if collider != null and collider.is_in_group("Interactable"):
			found = collider

	if found != null:
		_lost_target_time = 0.0
		if found != _current_target:
			_current_target = found
			interact_target_changed.emit(true)
			if debug_interact:
				print("Interact target: ", found.name)
	elif _current_target != null:
		_lost_target_time += delta
		if _lost_target_time >= interact_grace_time:
			_current_target = null
			interact_target_changed.emit(false)
			if debug_interact:
				print("Interact target: none")


func _update_footsteps(delta: float) -> void:
	if is_dead or not is_on_floor():
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed < 1.0:
		return
	_step_distance += speed * delta
	if _step_distance >= 2.2:
		_step_distance = 0.0
		if footstep_sound != null:
			footstep_sound.play()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var move_input: Vector2 = Vector2.ZERO
	if not is_dead:
		move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = transform.basis * Vector3(move_input.x, 0.0, move_input.y)
	direction = direction.normalized()

	var target_velocity: Vector3 = direction * walk_speed
	var rate: float = acceleration if direction.length() > 0.0 else friction
	var weight: float = minf(rate * delta, 1.0)
	velocity.x = lerpf(velocity.x, target_velocity.x, weight)
	velocity.z = lerpf(velocity.z, target_velocity.z, weight)

	move_and_slide()
	_update_footsteps(delta)
	_update_interaction_target(delta)

	if global_position.y < fall_kill_height and not is_dead:
		health.call("take_damage", 100000.0)

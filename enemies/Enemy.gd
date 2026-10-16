extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK }

@export_group("Body")
@export var enemy_health: float = 50.0
@export var enemy_color: Color = Color(0.75, 0.15, 0.15)

@export_group("Movement")
@export var chase_speed: float = 3.5
@export var acceleration: float = 28.0
@export var turn_speed: float = 8.0
@export var gravity: float = 20.0
@export var max_slope_degrees: float = 55.0
@export var jump_velocity: float = 6.0
@export var jump_cooldown: float = 1.0
@export var stuck_time_limit: float = 0.8
@export var path_update_interval: float = 0.25
@export var repath_distance: float = 1.0

@export_group("Senses")
@export var sight_range: float = 30.0
# Once alerted, the enemy sees this much further and in all directions
@export var alert_range_multiplier: float = 1.5
@export var sight_angle_degrees: float = 110.0
@export var sense_radius: float = 3.0
@export var lose_sight_time: float = 6.0
@export var vision_interval: float = 0.15

@export_group("Combat")
@export var attack_range: float = 1.7
@export var attack_damage: float = 10.0
@export var attack_interval: float = 1.0

@export_group("Debug")
@export var debug_ai: bool = false

var _state: State = State.IDLE
var _player: Node3D = null
var _sees_player: bool = false
var _last_known: Vector3 = Vector3.ZERO
var _lost_timer: float = 0.0
var _vision_timer: float = 0.0
var _path_timer: float = 0.0
var _attack_timer: float = 0.0
var _debug_timer: float = 0.0
var _is_dead: bool = false
var _warned_no_navmesh: bool = false
var _warned_direct: bool = false
var _material: StandardMaterial3D = null

var _desired_velocity: Vector3 = Vector3.ZERO
var _nav_target: Vector3 = Vector3.ZERO
var _has_nav_target: bool = false
var _jump_timer: float = 0.0
var _stuck_timer: float = 0.0
var _stuck_check_timer: float = 0.0
var _last_check_position: Vector3 = Vector3.ZERO
var _sidestep_timer: float = 0.0
var _sidestep_dir: Vector3 = Vector3.ZERO
var _step_distance: float = 0.0

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health: Node = $HealthComponent
@onready var hurt_sound: AudioStreamPlayer3D = get_node_or_null("HurtSound") as AudioStreamPlayer3D
@onready var death_sound: AudioStreamPlayer3D = get_node_or_null("DeathSound") as AudioStreamPlayer3D
@onready var footstep_sound: AudioStreamPlayer3D = get_node_or_null("FootstepSound") as AudioStreamPlayer3D


func _ready() -> void:
	# Slope handling: stick to hills and keep full speed uphill
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(max_slope_degrees)
	floor_constant_speed = true
	_last_check_position = global_position

	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	collision.position = Vector3(0.0, 0.9, 0.0)

	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.4
	capsule_mesh.height = 1.8
	mesh_instance.mesh = capsule_mesh
	mesh_instance.position = Vector3(0.0, 0.9, 0.0)
	_material = StandardMaterial3D.new()
	_material.albedo_color = enemy_color
	mesh_instance.material_override = _material

	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 1.0
	nav_agent.radius = 0.4

	health.set("max_health", enemy_health)
	health.set("current_health", enemy_health)
	health.connect("health_changed", Callable(self, "_on_health_changed"))
	health.connect("on_death", Callable(self, "_on_death"))


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# States fill this in; zero means "stand still"
	_desired_velocity = Vector3.ZERO

	if _player.get("is_dead") == true:
		_state = State.IDLE
		_sees_player = false
		_has_nav_target = false
	else:
		_update_senses(delta)

	match _state:
		State.IDLE:
			pass
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	_handle_obstacles(delta)

	# Smooth acceleration instead of instant speed changes (removes jitter)
	velocity.x = move_toward(velocity.x, _desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, _desired_velocity.z, acceleration * delta)
	move_and_slide()
	_update_footsteps(delta)

	if debug_ai:
		_debug_print(delta)


# ---------- Senses ----------

func _update_senses(delta: float) -> void:
	_vision_timer -= delta
	if _vision_timer > 0.0:
		return
	var far_and_idle: bool = _state == State.IDLE and global_position.distance_to(_player.global_position) > sight_range * 0.6
	_vision_timer = vision_interval * 3.0 if far_and_idle else vision_interval
	_vision_timer = vision_interval
	_sees_player = _can_see_player()
	if _sees_player:
		_last_known = _player.global_position
		_lost_timer = 0.0
		if _state == State.IDLE:
			_state = State.CHASE


func _can_see_player() -> bool:
	var alerted: bool = _state != State.IDLE
	var max_range: float = sight_range
	if alerted:
		max_range = sight_range * alert_range_multiplier

	var to_player: Vector3 = _player.global_position - global_position
	var distance: float = to_player.length()
	if distance > max_range:
		return false

	# Only an unaware enemy is limited to its vision cone
	if not alerted and distance > sense_radius:
		var forward: Vector3 = -global_basis.z
		var flat: Vector3 = Vector3(to_player.x, 0.0, to_player.z).normalized()
		var min_dot: float = cos(deg_to_rad(sight_angle_degrees * 0.5))
		if forward.dot(flat) < min_dot:
			return false

	# Three rays: head, chest, feet. Any clear ray = seen.
	var eye: Vector3 = global_position + Vector3(0.0, 1.6, 0.0)
	var base: Vector3 = _player.global_position
	var targets: Array[Vector3] = [
		base + Vector3(0.0, 1.6, 0.0),
		base + Vector3(0.0, 1.0, 0.0),
		base + Vector3(0.0, 0.3, 0.0),
	]
	for point: Vector3 in targets:
		if _ray_reaches_player(eye, point):
			return true
	return false


func _ray_reaches_player(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	return result["collider"] == _player


# ---------- States ----------

func _process_chase(delta: float) -> void:
	var to_player: Vector3 = _player.global_position - global_position
	var flat_distance: float = Vector2(to_player.x, to_player.z).length()

	if _sees_player and flat_distance <= attack_range:
		_state = State.ATTACK
		_attack_timer = 0.3
		return

	if not _sees_player:
		_lost_timer += delta
		if _lost_timer >= lose_sight_time:
			_state = State.IDLE
			_has_nav_target = false
			return

	# Only repath when the target has really moved: stops path flip-flopping
	_path_timer -= delta
	if _path_timer <= 0.0:
		_path_timer = path_update_interval
		if not _has_nav_target or _nav_target.distance_to(_last_known) > repath_distance:
			_nav_target = _last_known
			_has_nav_target = true
			nav_agent.target_position = _last_known
	_move_along_path(delta)


func _process_attack(delta: float) -> void:
	var to_player: Vector3 = _player.global_position - global_position
	_face(to_player, delta)

	var flat_distance: float = Vector2(to_player.x, to_player.z).length()
	if flat_distance > attack_range * 1.4 or not _sees_player:
		_state = State.CHASE
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_interval
		var player_health: Node = _player.get_node_or_null("HealthComponent")
		if player_health != null:
			player_health.call("take_damage", attack_damage)


# ---------- Movement helpers ----------

func _move_along_path(delta: float) -> void:
	var nav_map: RID = nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return
	if not _warned_no_navmesh and NavigationServer3D.map_get_regions(nav_map).is_empty():
		_warned_no_navmesh = true
		push_warning("Enemy: no navigation region found. Is the level set up and baked?")

	var to_target: Vector3 = _last_known - global_position
	var flat_to_target: float = Vector2(to_target.x, to_target.z).length()

	if nav_agent.is_navigation_finished():
		# The navmesh can't take us closer, but we can see the target: walk straight at it
		if flat_to_target > 2.5 and _sees_player:
			if not _warned_direct:
				_warned_direct = true
				push_warning("Enemy: navmesh does not reach the target, walking straight.")
			_set_move_direction(to_target, delta)
		return

	var next_position: Vector3 = nav_agent.get_next_path_position()
	_set_move_direction(next_position - global_position, delta)


func _set_move_direction(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length() < 0.05:
		return
	direction = direction.normalized()
	_desired_velocity = direction * chase_speed
	_face(direction, delta)


func _handle_obstacles(delta: float) -> void:
	_jump_timer = maxf(_jump_timer - delta, 0.0)

	# While sidestepping, override where we're heading
	if _sidestep_timer > 0.0:
		_sidestep_timer -= delta
		_desired_velocity = _sidestep_dir * chase_speed

	if _desired_velocity.length() < 0.1:
		_stuck_timer = 0.0
		_stuck_check_timer = 0.0
		_last_check_position = global_position
		return

	# Hop over small ledges: pushing into something while on the ground
	if is_on_floor() and is_on_wall() and _jump_timer <= 0.0:
		velocity.y = jump_velocity
		_jump_timer = jump_cooldown

	# Stuck detection: trying to move but barely progressing
	_stuck_check_timer += delta
	if _stuck_check_timer >= 0.4:
		var moved: float = Vector2(
			global_position.x - _last_check_position.x,
			global_position.z - _last_check_position.z).length()
		if moved < 0.15:
			_stuck_timer += _stuck_check_timer
		else:
			_stuck_timer = 0.0
		_last_check_position = global_position
		_stuck_check_timer = 0.0

	if _stuck_timer >= stuck_time_limit and _sidestep_timer <= 0.0:
		_stuck_timer = 0.0
		var forward: Vector3 = _desired_velocity.normalized()
		var side: float = 1.0 if randf() < 0.5 else -1.0
		_sidestep_dir = Vector3(-forward.z, 0.0, forward.x) * side
		_sidestep_timer = 0.6
		# Force a fresh path afterwards
		_has_nav_target = false
		_path_timer = 0.0


func _update_footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed < 0.5:
		return
	_step_distance += speed * delta
	if _step_distance >= 1.8:
		_step_distance = 0.0
		if footstep_sound != null:
			footstep_sound.play()


func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


# ---------- Health ----------

func _on_health_changed(_current: float, _maximum: float) -> void:
	if _current > 0.0 and hurt_sound != null:
		hurt_sound.play()
	_material.albedo_color = Color.WHITE
	create_tween().tween_property(_material, "albedo_color", enemy_color, 0.15)
	# Getting shot alerts an idle enemy
	if _player != null and _state == State.IDLE:
		_state = State.CHASE
		_last_known = _player.global_position
		_lost_timer = 0.0
		_has_nav_target = false


func _on_death() -> void:
	if death_sound != null:
		death_sound.play()
	_is_dead = true
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", true)
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation:x", -PI * 0.5, 0.5)
	tween.tween_interval(3.0)
	tween.tween_callback(queue_free)


# ---------- Debug ----------

func _debug_print(delta: float) -> void:
	_debug_timer -= delta
	if _debug_timer > 0.0:
		return
	_debug_timer = 1.0
	print("Enemy ", name, ": state=", State.keys()[_state], " sees=", _sees_player,
		" nav_finished=", nav_agent.is_navigation_finished(), " on_floor=", is_on_floor(),
		" stuck=", snappedf(_stuck_timer, 0.1))

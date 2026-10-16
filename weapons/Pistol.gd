extends Node3D

signal ammo_changed(current_mag: int, reserve: int)
signal reloaded
signal out_of_ammo
signal shot_fired
signal recoil_request(pitch: float, yaw: float)

@export_group("Ammo")
@export var mag_size: int = 12
@export var reserve_ammo: int = 60
@export var reload_time: float = 1.4

@export_group("Fire rate")
@export var shots_per_second: float = 4.0
@export var max_range: float = 60.0

@export_group("Spread")
@export var spread_hip_deg: float = 2.0
@export var spread_aim_deg: float = 0.4

@export_group("Damage falloff")
@export var damage_near: float = 25.0
@export var damage_far: float = 8.0
@export var damage_near_range: float = 10.0
@export var damage_far_range: float = 45.0
@export var headshot_mult: float = 2.0

@export_group("Ballistics")
@export var muzzle_velocity: float = 250.0
@export var bullet_gravity: float = 9.8
@export var bullet_drag: float = 0.02
@export var ballistic_step_length: float = 1.0

@export_group("Tracers")
@export var tracer_enabled: bool = true
@export var tracer_life: float = 0.05

@export_group("Recoil")
@export var recoil_pitch: float = 1.2
@export var recoil_yaw: float = 0.4
@export var allow_camera_kick: bool = true

@export_group("Model")
@export var use_placeholder_model: bool = true

var _cooldown: float = 0.0
var _ammo_in_mag: int = 0
var _reloading: bool = false
var _aiming: bool = false
var _rng := RandomNumberGenerator.new()
var _rest_transform: Transform3D = Transform3D.IDENTITY
var _recoil_tween: Tween = null
var muzzle: Node3D = null

@onready var shot_sound: AudioStreamPlayer = get_node_or_null("ShotSound") as AudioStreamPlayer
@onready var reload_sound: AudioStreamPlayer = get_node_or_null("ReloadSound") as AudioStreamPlayer
@onready var dry_sound: AudioStreamPlayer = get_node_or_null("DrySound") as AudioStreamPlayer
@onready var impact_sound: AudioStreamPlayer3D = get_node_or_null("ImpactSound") as AudioStreamPlayer3D


func _ready() -> void:
	_rng.randomize()
	_rest_transform = transform
	_ammo_in_mag = mag_size
	if use_placeholder_model:
		_build_placeholder_model()


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	# Smoothly slerp the rotation kick back to rest each frame
	var t: Transform3D = transform
	var from_q: Quaternion = t.basis.orthonormalized().get_rotation_quaternion()
	var to_q: Quaternion = _rest_transform.basis.orthonormalized().get_rotation_quaternion()
	var blend: float = clampf(delta * 10.0, 0.0, 1.0)
	var q: Quaternion = from_q.slerp(to_q, blend)
	t.basis = Basis(q)
	transform = t


func set_aiming(enabled: bool) -> void:
	_aiming = enabled


func reload() -> void:
	if _reloading or _ammo_in_mag >= mag_size or reserve_ammo <= 0:
		return

	_reloading = true
	if reload_sound != null:
		reload_sound.play()

	get_tree().create_timer(reload_time).timeout.connect(_finish_reload)


func _finish_reload() -> void:
	var needed: int = mag_size - _ammo_in_mag
	var to_load: int = mini(needed, reserve_ammo)
	_ammo_in_mag += to_load
	reserve_ammo -= to_load
	_reloading = false

	reloaded.emit()
	ammo_changed.emit(_ammo_in_mag, reserve_ammo)


func fire() -> void:
	if _reloading or _cooldown > 0.0:
		return

	if _ammo_in_mag <= 0:
		if dry_sound != null:
			dry_sound.play()
		out_of_ammo.emit()
		_cooldown = 0.18
		return

	_cooldown = 1.0 / shots_per_second
	_ammo_in_mag -= 1
	ammo_changed.emit(_ammo_in_mag, reserve_ammo)

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	if shot_sound != null:
		shot_sound.pitch_scale = _rng.randf_range(0.96, 1.04)
		shot_sound.play()

	_kick_recoil(camera)
	_spawn_muzzle_flash()

	var spread_rad: float = deg_to_rad(spread_aim_deg if _aiming else spread_hip_deg)
	var fwd: Vector3 = -camera.global_basis.z
	var right: Vector3 = camera.global_basis.x
	var up: Vector3 = camera.global_basis.y
	var pitch_off: float = _rng.randf_range(-spread_rad, spread_rad)
	var yaw_off: float = _rng.randf_range(-spread_rad, spread_rad)
	var dir: Vector3 = fwd.rotated(right, pitch_off).rotated(up, yaw_off).normalized()

	var origin: Vector3 = camera.global_position

	var hit: Dictionary = _ballistic_cast(origin, dir, muzzle_velocity, bullet_gravity, bullet_drag, max_range, ballistic_step_length)

	if hit.is_empty():
		if tracer_enabled:
			_spawn_tracer(origin, origin + dir * max_range, max_range / muzzle_velocity)
		shot_fired.emit()
		return

	var hit_pos: Vector3 = hit["position"]
	var distance: float = hit["distance"]
	var tof: float = hit["time"]
	var collider: Object = hit["collider"]

	if tracer_enabled:
		_spawn_tracer(origin, hit_pos, maxf(tof, tracer_life))

	if tof <= 0.01:
		_process_impact(collider, hit_pos, distance)
	else:
		get_tree().create_timer(tof).timeout.connect(func() -> void:
			_process_impact(collider, hit_pos, distance)
		)

	shot_fired.emit()


func _process_impact(collider: Object, hit_pos: Vector3, distance: float) -> void:
	_spawn_impact(hit_pos)
	if impact_sound != null:
		impact_sound.global_position = hit_pos
		impact_sound.play()
	_apply_damage(collider, hit_pos, distance)


func _kick_recoil(camera: Camera3D) -> void:
	var kick_pos := Vector3(0.0, 0.01, 0.055)
	var kick_rot_x: float = deg_to_rad(-5.0)
	var kick_rot_y: float = deg_to_rad(_rng.randf_range(-2.0, 2.0))

	var kicked_basis: Basis = _rest_transform.basis.rotated(Vector3.RIGHT, kick_rot_x).rotated(Vector3.UP, kick_rot_y)
	var tmp: Transform3D = transform
	tmp.basis = kicked_basis
	transform = tmp

	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()

	_recoil_tween = create_tween()
	_recoil_tween.tween_property(self, "transform:origin", _rest_transform.origin + kick_pos, 0.035).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(self, "transform:origin", _rest_transform.origin, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if allow_camera_kick and camera != null:
		var yaw_kick: float = _rng.randf_range(-recoil_yaw, recoil_yaw)
		var pitch_kick: float = recoil_pitch
		if camera.has_method("add_view_kick"):
			camera.call("add_view_kick", pitch_kick, yaw_kick)
		else:
			var rot: Vector3 = camera.rotation_degrees
			rot.x = clampf(rot.x - pitch_kick, -89.0, 89.0)
			rot.y += yaw_kick
			camera.rotation_degrees = rot

	recoil_request.emit(recoil_pitch, recoil_yaw)


func _ballistic_cast(origin: Vector3, dir: Vector3, v0: float, g: float, drag: float, limit_dist: float, step_len: float) -> Dictionary:
	var dss := get_world_3d().direct_space_state
	var pos := origin
	var vel := dir * v0
	var traveled: float = 0.0
	var total_time: float = 0.0

	var excludes: Array[RID] = []
	var shooter := _find_shooter_collider()
	if shooter != null:
		excludes.append(shooter.get_rid())

	while traveled < limit_dist:
		var speed: float = vel.length()
		if speed <= 0.1:
			break

		var dt: float = step_len / speed
		var next_pos: Vector3 = pos + vel * dt

		var params := PhysicsRayQueryParameters3D.create(pos, next_pos)
		params.exclude = excludes
		var result: Dictionary = dss.intersect_ray(params)

		if not result.is_empty():
			var hit_pos: Vector3 = result["position"]
			var seg_dist: float = pos.distance_to(hit_pos)
			return {
				"position": hit_pos,
				"normal": result["normal"],
				"collider": result["collider"],
				"distance": traveled + seg_dist,
				"time": total_time + (seg_dist / speed)
			}

		pos = next_pos
		vel *= maxf(0.0, 1.0 - drag * dt)
		vel += Vector3.DOWN * g * dt
		traveled += step_len
		total_time += dt

	return {}


func _find_shooter_collider() -> CollisionObject3D:
	var node: Node = self
	while node != null:
		if node is CollisionObject3D:
			return node as CollisionObject3D
		node = node.get_parent()
	return null


func _calc_damage(distance: float, is_headshot: bool) -> float:
	var t: float = clampf((distance - damage_near_range) / maxf(0.001, (damage_far_range - damage_near_range)), 0.0, 1.0)
	var base: float = lerpf(damage_near, damage_far, t)
	if is_headshot:
		base *= headshot_mult
	return base


func _apply_damage(collider: Object, hit_pos: Vector3, distance: float) -> void:
	var target := collider as Node
	if target == null:
		return

	var is_head: bool = target.is_in_group("hitbox_head") or str(target.name).to_lower().contains("head")
	var final_damage: float = _calc_damage(distance, is_head)

	var health: Node = target.get_node_or_null("HealthComponent")
	if health == null and target.get_parent() != null:
		health = target.get_parent().get_node_or_null("HealthComponent")

	if health != null and health.has_method("take_damage"):
		health.call("take_damage", final_damage)
	elif target.has_method("take_damage"):
		target.call("take_damage", final_damage)


func _spawn_muzzle_flash() -> void:
	var parent: Node3D = muzzle if muzzle != null else self
	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(10.0, 7.0, 3.0)
	mat.albedo_color = Color(1.0, 0.85, 0.5, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat

	flash.mesh = quad
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_transform = parent.global_transform
	flash.scale = Vector3.ONE * _rng.randf_range(0.8, 1.2)

	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector3.ZERO, 0.05)
	tw.finished.connect(flash.queue_free)


func _spawn_tracer(from: Vector3, to: Vector3, life: float) -> void:
	var tracer := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(3.5, 3.5, 1.2)
	mat.albedo_color = Color(1.0, 0.95, 0.4)
	sphere.material = mat

	tracer.mesh = sphere
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = from

	var tw := tracer.create_tween()
	tw.tween_property(tracer, "global_position", to, maxf(0.02, life))
	tw.finished.connect(tracer.queue_free)


func _spawn_impact(point: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(3.0, 2.2, 1.0)
	sphere.material = mat

	spark.mesh = sphere
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(spark)
	spark.global_position = point

	var tw := spark.create_tween()
	tw.tween_property(spark, "scale", Vector3.ZERO, 0.09)
	tw.finished.connect(spark.queue_free)


func _build_placeholder_model() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.10, 0.30)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14)
	mat.metallic = 0.6
	mat.roughness = 0.4
	box.material = mat
	body.mesh = box
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)

	if get_node_or_null("Muzzle") == null:
		var m := Node3D.new()
		m.name = "Muzzle"
		add_child(m)
		m.position = Vector3(0.0, 0.04, -0.16)
		muzzle = m
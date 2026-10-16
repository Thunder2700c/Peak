extends SpotLight3D
# AAA-style flashlight: soft hotspot, dim spill, shadows, hand lag,
# walking sway, power-on stutter and a rare flicker.

@export_group("Beam")
@export var beam_energy: float = 6.0
@export var beam_range: float = 30.0
@export var beam_angle: float = 30.0
@export var light_tint: Color = Color(1.0, 0.95, 0.84)

@export_group("Spill")
@export var spill_energy: float = 0.7
@export var spill_angle: float = 70.0
@export var spill_range: float = 14.0

@export_group("Motion")
# Higher = follows the camera tighter. 100 = no lag.
@export var follow_speed: float = 14.0
# Sway strength in degrees. 0 = none.
@export var sway_amount: float = 0.6

@export_group("Flicker")
@export var enable_flicker: bool = true
@export var flicker_min_delay: float = 8.0
@export var flicker_max_delay: float = 20.0

@export_group("Forward+ only")
# Ignored on the Mobile renderer.
@export var volumetric_fog_energy: float = 8.0

# Fade multiplier used by toggle(): 0 = off, 1 = fully on
var intensity: float = 1.0

var _spill: SpotLight3D = null
var _smoothed_basis: Basis = Basis.IDENTITY
var _is_on: bool = true
var _fade_tween: Tween = null
var _flicker_timer: float = 0.0
var _flicker_left: float = 0.0
var _sway_time: float = 0.0
var _rest_position: Vector3 = Vector3.ZERO
var _player: CharacterBody3D = null


func _ready() -> void:
	_player = owner as CharacterBody3D
	_rest_position = position
	_setup_main_light()
	_setup_spill_light()
	var parent_3d: Node3D = get_parent_node_3d()
	if parent_3d != null:
		_smoothed_basis = parent_3d.global_basis.orthonormalized()
	_reset_flicker_timer()
	_is_on = false
	intensity = 0.0
	visible = false


func toggle() -> void:
	set_on(not _is_on)


func set_on(value: bool) -> void:
	if value == _is_on:
		return
	_is_on = value
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	if _is_on:
		visible = true
		# Quick power-on stutter, then full brightness
		_fade_tween.tween_property(self, "intensity", 0.6, 0.04)
		_fade_tween.tween_property(self, "intensity", 0.1, 0.05)
		_fade_tween.tween_property(self, "intensity", 1.0, 0.12)
	else:
		_fade_tween.tween_property(self, "intensity", 0.0, 0.10)
		_fade_tween.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	var parent_3d: Node3D = get_parent_node_3d()
	if parent_3d == null:
		return

	# 1) Lag behind camera rotation (kept clean, no sway stored in it)
	var weight: float = clampf(follow_speed * delta, 0.0, 1.0)
	var target: Basis = parent_3d.global_basis.orthonormalized()
	_smoothed_basis = _smoothed_basis.slerp(target, weight).orthonormalized()
	global_basis = _smoothed_basis

	# 2) Sway and small bob, stronger while walking
	var speed: float = 0.0
	if _player != null:
		speed = Vector2(_player.velocity.x, _player.velocity.z).length()
	var walk_factor: float = clampf(speed / 5.0, 0.0, 1.0)
	_sway_time += delta * (2.0 + walk_factor * 6.0)
	var sway: float = deg_to_rad(sway_amount) * (0.25 + walk_factor)
	rotate_object_local(Vector3.RIGHT, sin(_sway_time) * sway)
	rotate_object_local(Vector3.UP, cos(_sway_time * 0.5) * sway)
	position = _rest_position + Vector3(0.0, sin(_sway_time * 2.0) * 0.01 * walk_factor, 0.0)

	# 3) Brightness = base * fade * flicker
	var level: float = intensity * _update_flicker(delta)
	light_energy = beam_energy * level
	if _spill != null:
		_spill.light_energy = spill_energy * level


func _update_flicker(delta: float) -> float:
	var micro: float = 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.015
	if not enable_flicker or not _is_on:
		return micro
	if _flicker_left > 0.0:
		_flicker_left -= delta
		return randf_range(0.15, 0.9)
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_left = randf_range(0.15, 0.35)
		_reset_flicker_timer()
	return micro


func _reset_flicker_timer() -> void:
	_flicker_timer = randf_range(flicker_min_delay, flicker_max_delay)


func _setup_main_light() -> void:
	light_color = light_tint
	light_energy = beam_energy
	spot_range = beam_range
	spot_angle = beam_angle
	spot_attenuation = 1.3
	spot_angle_attenuation = 1.2
	shadow_enabled = true  # required for the projector texture
	light_projector = _make_projector()
	light_volumetric_fog_energy = volumetric_fog_energy


func _setup_spill_light() -> void:
	_spill = SpotLight3D.new()
	_spill.light_color = light_tint
	_spill.light_energy = spill_energy
	_spill.spot_range = spill_range
	_spill.spot_angle = spill_angle
	_spill.spot_attenuation = 1.5
	_spill.spot_angle_attenuation = 1.5
	_spill.light_specular = 0.0
	_spill.shadow_enabled = false
	add_child(_spill)


func _make_projector() -> GradientTexture2D:
	# White-warm hotspot, soft falloff, slightly cooler edge
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.98, 0.92))
	gradient.set_color(1, Color(0.0, 0.0, 0.0))
	gradient.add_point(0.15, Color(0.98, 0.97, 0.92))
	gradient.add_point(0.40, Color(0.70, 0.71, 0.72))
	gradient.add_point(0.70, Color(0.25, 0.27, 0.30))
	gradient.add_point(0.90, Color(0.08, 0.09, 0.11))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 512
	tex.height = 512
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

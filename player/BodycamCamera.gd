extends Camera3D
# Body-cam feel: wide lens, handheld sway, chest bounce while moving.

@export var lens_fov: float = 82.0
@export var idle_sway_degrees: float = 0.3
@export var walk_sway_degrees: float = 0.6
@export var walk_bob_height: float = 0.03
@export var walk_roll_degrees: float = 0.7

var _time: float = 0.0
var _walk_time: float = 0.0
var _rest_position: Vector3 = Vector3.ZERO
var _player: CharacterBody3D = null


func _ready() -> void:
	fov = lens_fov
	_rest_position = position
	_player = owner as CharacterBody3D


func _process(delta: float) -> void:
	var speed: float = 0.0
	if _player != null:
		speed = Vector2(_player.velocity.x, _player.velocity.z).length()
	var walk: float = clampf(speed / 5.0, 0.0, 1.0)

	_time += delta
	_walk_time += delta * 9.0 * walk

	var sway: float = deg_to_rad(lerpf(idle_sway_degrees, walk_sway_degrees, walk))
	var pitch: float = (sin(_time * 0.9) * 0.6 + sin(_time * 2.1) * 0.4) * sway
	var yaw: float = (sin(_time * 0.7 + 1.3) * 0.6 + sin(_time * 1.9) * 0.4) * sway
	var roll: float = sin(_walk_time) * deg_to_rad(walk_roll_degrees) * walk + sin(_time * 0.5) * sway * 0.5
	rotation = Vector3(pitch, yaw, roll)

	var bob: float = sin(_walk_time * 2.0) * walk_bob_height * walk
	position = _rest_position + Vector3(0.0, bob, 0.0)

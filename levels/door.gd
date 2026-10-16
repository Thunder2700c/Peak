extends StaticBody3D

@export var open_angle_degrees: float = 90.0
@export var open_time: float = 0.8

var is_open: bool = false
var _closed_rotation_y: float = 0.0
var _tween: Tween = null

@onready var door_sound: AudioStreamPlayer3D = get_node_or_null("DoorSound") as AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("Interactable")
	_closed_rotation_y = rotation_degrees.y


func interact() -> void:
	if door_sound != null:
		door_sound.play()
	is_open = not is_open
	var target: float = _closed_rotation_y
	if is_open:
		target = _closed_rotation_y + open_angle_degrees

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation_degrees:y", target, open_time)

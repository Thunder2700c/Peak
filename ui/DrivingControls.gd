extends Control

signal throttle_changed(value: float)
signal steer_changed(value: float)
signal handbrake_changed(value: bool)
signal exit_pressed

@onready var handbrake_button: Button = $HandbrakeButton
@onready var exit_button: Button = $ExitButton


func _ready() -> void:
	handbrake_button.button_down.connect(_on_handbrake_down)
	handbrake_button.button_up.connect(_on_handbrake_up)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_handbrake_down() -> void:
	handbrake_changed.emit(true)


func _on_handbrake_up() -> void:
	handbrake_changed.emit(false)


func _on_exit_pressed() -> void:
	exit_pressed.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	steer_changed.emit(v.x)
	throttle_changed.emit(-v.y)

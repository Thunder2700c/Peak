extends Node

@onready var player = $Player
@onready var touch_controls = $UI/MobileTouchControls
@onready var hud = $UI/HUD
@onready var driving_controls = $UI/DrivingControls
@onready var car = $Car  # confirm this matches the real node name in your tree
@onready var car_entry = $Car/EnterZone
@onready var car_camera = $Car/DriverSeatCamera/Camera3D
@onready var player_camera = $Player/Head/Camera3D

var _in_car: bool = false


func _ready() -> void:
	touch_controls.connect("look_dragged", Callable(player, "apply_look"))
	touch_controls.connect("flashlight_pressed", Callable(player, "toggle_flashlight"))
	touch_controls.connect("interact_pressed", Callable(player, "try_interact"))
	touch_controls.connect("fire_pressed", Callable(player, "fire_weapon"))
	player.connect("interact_target_changed", Callable(touch_controls, "set_interact_visible"))
	player.connect("health_changed", Callable(hud, "set_health"))
	player.connect("died", Callable(hud, "show_dead"))
	hud.connect("restart_pressed", Callable(self, "_restart"))
	hud.connect("save_pressed", Callable(self, "_save"))

	driving_controls.connect("throttle_changed", Callable(car, "set_throttle"))
	driving_controls.connect("steer_changed", Callable(car, "set_steer"))
	driving_controls.connect("handbrake_changed", Callable(car, "set_handbrake"))

	car_entry.connect("player_entered_car", Callable(self, "_enter_car"))
	driving_controls.connect("exit_pressed", Callable(self, "_exit_car"))
	driving_controls.visible = false

	if GameManager.has_save:
		GameManager.load_into(player)


func _enter_car(_car_node: Node) -> void:
	_in_car = true
	player.visible = false
	player.set_physics_process(false)
	car_camera.current = true
	driving_controls.visible = true
	touch_controls.visible = false


func _exit_car() -> void:
	_in_car = false
	car.call("stop_driving")
	player.global_position = car.get_node("ExitPoint").global_position
	player.visible = true
	player.set_physics_process(true)
	player_camera.current = true
	driving_controls.visible = false
	touch_controls.visible = true
	car_entry.call("exit_car")


func _restart() -> void:
	GameManager.erase_save()
	get_tree().reload_current_scene()


func _save() -> void:
	GameManager.save_game(player)
	hud.call("show_save_confirmation")

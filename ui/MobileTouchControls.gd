extends Control

signal look_dragged(relative: Vector2)
signal flashlight_pressed
signal interact_pressed
signal fire_pressed

const NO_FINGER: int = -1

var _look_finger: int = NO_FINGER

@onready var joystick: Control = $VirtualJoystick
@onready var flashlight_button: Button = $FlashlightButton
@onready var interact_button: Button = $InteractButton
@onready var fire_button: Button = $FireButton
@onready var click_sound: AudioStreamPlayer = get_node_or_null("ClickSound") as AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var white_style: StyleBoxFlat = _make_button_style(Color(1.0, 1.0, 1.0, 0.7))
	var fire_style: StyleBoxFlat = _make_button_style(Color(1.0, 0.4, 0.35, 0.9))
	for button: Button in [flashlight_button, interact_button, fire_button]:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 28)
	flashlight_button.add_theme_stylebox_override("normal", white_style)
	interact_button.add_theme_stylebox_override("normal", white_style)
	fire_button.add_theme_stylebox_override("normal", fire_style)
	flashlight_button.text = "Light"
	interact_button.text = "USE"
	fire_button.text = "FIRE"
	interact_button.visible = false
	_style_joystick()
	resized.connect(_layout_buttons)
	_layout_buttons()


func set_interact_visible(value: bool) -> void:
	interact_button.visible = value


func _make_button_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(100)
	return style


func _style_joystick() -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	base.border_color = Color(1.0, 1.0, 1.0, 0.35)
	base.set_border_width_all(3)
	base.set_corner_radius_all(300)
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(1.0, 1.0, 1.0, 0.35)
	tip.set_corner_radius_all(300)
	joystick.add_theme_stylebox_override("normal_joystick", base)
	joystick.add_theme_stylebox_override("pressed_joystick", base)
	joystick.add_theme_stylebox_override("normal_tip", tip)
	joystick.add_theme_stylebox_override("pressed_tip", tip)


func _layout_buttons() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var unit: float = screen.y
	var margin: float = unit * 0.06
	var gap: float = unit * 0.04
	var fire_size: float = unit * 0.17
	var use_size: float = unit * 0.14
	var light_size: float = unit * 0.11

	fire_button.size = Vector2(fire_size, fire_size)
	fire_button.position = Vector2(screen.x - margin - fire_size, screen.y - margin - fire_size)

	interact_button.size = Vector2(use_size, use_size)
	interact_button.position = Vector2(
		screen.x - margin - fire_size * 0.5 - use_size * 0.5,
		fire_button.position.y - gap - use_size)

	flashlight_button.size = Vector2(light_size, light_size)
	flashlight_button.position = Vector2(screen.x - margin - light_size, margin)

	var font_size: int = maxi(int(unit * 0.03), 14)
	for button: Button in [flashlight_button, interact_button, fire_button]:
		button.add_theme_font_size_override("font_size", font_size)
	queue_redraw()


func _draw() -> void:
	# Crosshair at the exact screen center (where bullets go)
	var center: Vector2 = get_viewport_rect().size * 0.5
	draw_circle(center, 3.0, Color(1.0, 1.0, 1.0, 0.85))
	draw_arc(center, 12.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.45), 2.0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _hit(button: Button, pos: Vector2) -> bool:
	return button.visible and button.get_global_rect().has_point(pos)


func _flash(button: Button) -> void:
	if button != fire_button and click_sound != null:
		click_sound.play()
	button.modulate = Color(1.0, 1.0, 1.0, 0.35)
	create_tween().tween_property(button, "modulate", Color.WHITE, 0.25)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _hit(flashlight_button, event.position):
			_flash(flashlight_button)
			flashlight_pressed.emit()
			return
		if _hit(interact_button, event.position):
			_flash(interact_button)
			interact_pressed.emit()
			return
		if _hit(fire_button, event.position):
			_flash(fire_button)
			fire_pressed.emit()
			# This finger can also drag to aim while shooting
			if _look_finger == NO_FINGER:
				_look_finger = event.index
			return
		var screen_width: float = get_viewport_rect().size.x
		if event.position.x >= screen_width * 0.5 and _look_finger == NO_FINGER:
			_look_finger = event.index
	elif event.index == _look_finger:
		_look_finger = NO_FINGER


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _look_finger:
		look_dragged.emit(event.relative)

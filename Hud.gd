extends Control

signal restart_pressed
signal save_pressed

var _current: float = 100.0
var _maximum: float = 100.0
var _flash: float = 0.0
var _dead: bool = false
var _restart_sent: bool = false
var _save_flash_timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_health(current: float, maximum: float) -> void:
	if current < _current:
		_flash = 0.6
	_current = current
	_maximum = maximum
	queue_redraw()


func show_dead() -> void:
	_dead = true
	queue_redraw()


func show_save_confirmation() -> void:
	_save_flash_timer = 1.2
	queue_redraw()


func _process(delta: float) -> void:
	var needs_redraw: bool = false
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 1.5, 0.0)
		needs_redraw = true
	if _save_flash_timer > 0.0:
		_save_flash_timer = maxf(_save_flash_timer - delta, 0.0)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _restart_rect() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var button_size := Vector2(screen.y * 0.55, screen.y * 0.14)
	return Rect2(Vector2((screen.x - button_size.x) * 0.5, screen.y * 0.62), button_size)


func _save_rect() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var button_size := Vector2(screen.y * 0.16, screen.y * 0.08)
	return Rect2(Vector2(screen.y * 0.06, screen.y * 0.17), button_size)


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if not touch.pressed:
		return
	if _dead and not _restart_sent and _restart_rect().has_point(touch.position):
		_restart_sent = true
		restart_pressed.emit()
	elif not _dead and _save_rect().has_point(touch.position):
		save_pressed.emit()


func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var unit: float = screen.y
	var bar_pos := Vector2(unit * 0.06, unit * 0.09)
	var bar_size := Vector2(unit * 0.42, unit * 0.035)
	var ratio: float = 0.0
	if _maximum > 0.0:
		ratio = clampf(_current / _maximum, 0.0, 1.0)

	draw_rect(Rect2(bar_pos, bar_size), Color(0.0, 0.0, 0.0, 0.45))
	var fill_color := Color(0.95, 0.95, 0.95, 0.9)
	if ratio < 0.3:
		fill_color = Color(0.9, 0.2, 0.2, 0.9)
	draw_rect(Rect2(bar_pos, Vector2(bar_size.x * ratio, bar_size.y)), fill_color)
	draw_rect(Rect2(bar_pos, bar_size), Color(1.0, 1.0, 1.0, 0.6), false, 2.0)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(int(unit * 0.03), 14)
	draw_string(font, bar_pos + Vector2(0.0, -unit * 0.012), "HP %d" % int(ceil(_current)),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 1.0, 1.0, 0.9))

	if not _dead:
		var save_button: Rect2 = _save_rect()
		draw_rect(save_button, Color(0.1, 0.3, 0.55, 0.75))
		draw_rect(save_button, Color(1.0, 1.0, 1.0, 0.7), false, 2.0)
		draw_string(font, Vector2(save_button.position.x, save_button.position.y + save_button.size.y * 0.68),
			"SAVE", HORIZONTAL_ALIGNMENT_CENTER, save_button.size.x, int(unit * 0.03), Color(1.0, 1.0, 1.0, 1.0))

	if _save_flash_timer > 0.0:
		var alpha: float = clampf(_save_flash_timer, 0.0, 1.0)
		draw_string(font, Vector2(0.0, unit * 0.34), "Game saved",
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, int(unit * 0.035), Color(0.6, 1.0, 0.6, alpha))

	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.8, 0.0, 0.0, _flash * 0.5))
	if _dead:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.5))
		draw_string(font, Vector2(0.0, screen.y * 0.5), "YOU DIED",
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, int(unit * 0.09), Color(0.9, 0.1, 0.1, 1.0))
		var button: Rect2 = _restart_rect()
		draw_rect(button, Color(0.6, 0.1, 0.1, 0.85))
		draw_rect(button, Color(1.0, 1.0, 1.0, 0.8), false, 3.0)
		draw_string(font, Vector2(button.position.x, button.position.y + button.size.y * 0.68),
			"RESTART", HORIZONTAL_ALIGNMENT_CENTER, button.size.x, int(unit * 0.06), Color(1.0, 1.0, 1.0, 1.0))

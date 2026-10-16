extends Node

signal health_changed(current: float, maximum: float)
signal on_death

@export var max_health: float = 30.0

var current_health: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		on_death.emit()

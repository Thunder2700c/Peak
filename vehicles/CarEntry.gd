extends Area3D

signal player_entered_car(car: Node)
signal player_exited_car(car: Node)

var _car: Node = null
var _occupied: bool = false


func _ready() -> void:
	_car = get_parent()


func interact() -> void:
	if _occupied:
		return
	_occupied = true
	player_entered_car.emit(_car)


func exit_car() -> void:
	_occupied = false
	player_exited_car.emit(_car)

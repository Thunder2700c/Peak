extends Node
# Hides/shows hand-placed TrafficCar instances based on distance from the player.
# Builds nothing — only toggles visibility/physics on cars you placed in the editor.

@export var despawn_distance: float = 80.0

var _player: Node3D = null
var _cars: Array[Node3D] = []


func register_car(car: Node3D) -> void:
	_cars.append(car)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return

	for car in _cars:
		if not is_instance_valid(car):
			continue
		var distance: float = car.global_position.distance_to(_player.global_position)
		var should_be_active: bool = distance <= despawn_distance
		if car.visible != should_be_active:
			car.visible = should_be_active
			car.set_physics_process(should_be_active)
			car.freeze = not should_be_active

extends Node3D
# Loads/unloads hand-built chunk scenes based on distance from the player.
# Builds NOTHING itself — every chunk is a .tscn file you made in the editor.

@export var chunk_size: float = 128.0
@export var load_radius: int = 1  # 1 = a 3x3 grid of chunks stays loaded

# Map grid coordinate (e.g. "0,0") to the chunk's scene file path
var chunk_paths: Dictionary = {
	"0,0": "res://levels/chunks/chunk_0_0.tscn",
	"0,1": "res://levels/chunks/chunk_0_1.tscn",
}

var _loaded: Dictionary = {}  # grid coordinate -> instanced Node
var _player: Node3D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return

	var center_x: int = int(round(_player.global_position.x / chunk_size))
	var center_z: int = int(round(_player.global_position.z / chunk_size))

	var wanted: Dictionary = {}
	for x in range(center_x - load_radius, center_x + load_radius + 1):
		for z in range(center_z - load_radius, center_z + load_radius + 1):
			var key: String = "%d,%d" % [x, z]
			if chunk_paths.has(key):
				wanted[key] = true

	# Load anything wanted that isn't loaded yet
	for key: String in wanted.keys():
		if not _loaded.has(key):
			_load_chunk(key)

	# Unload anything loaded that's no longer wanted
	for key: String in _loaded.keys().duplicate():
		if not wanted.has(key):
			_unload_chunk(key)


func _load_chunk(key: String) -> void:
	var path: String = chunk_paths[key]
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path) as PackedScene
	var instance: Node3D = scene.instantiate() as Node3D
	add_child(instance)

	var parts: PackedStringArray = key.split(",")
	instance.position = Vector3(int(parts[0]) * chunk_size, 0.0, int(parts[1]) * chunk_size)
	_loaded[key] = instance


func _unload_chunk(key: String) -> void:
	var instance: Node = _loaded[key]
	instance.queue_free()
	_loaded.erase(key)

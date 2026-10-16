extends Node

const SAVE_PATH: String = "user://savegame.json"

var has_save: bool = false


func _ready() -> void:
	has_save = FileAccess.file_exists(SAVE_PATH)


func save_game(player: Node) -> void:
	var data: Dictionary = {
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"position_z": player.global_position.z,
		"look_y": player.rotation.y,
		"look_x": player.get_node("Head").rotation.x,
		"health": player.get_node("HealthComponent").get("current_health"),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameManager: could not open save file for writing")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	has_save = true


func load_into(player: Node) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("GameManager: save file is corrupted")
		return false
	var data: Dictionary = parsed as Dictionary

	player.global_position = Vector3(data.get("position_x", 0.0), data.get("position_y", 1.0), data.get("position_z", 0.0))
	player.rotation.y = data.get("look_y", 0.0)
	player.get_node("Head").rotation.x = data.get("look_x", 0.0)
	var health: Node = player.get_node("HealthComponent")
	health.set("current_health", data.get("health", health.get("max_health")))
	return true


func erase_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	has_save = false

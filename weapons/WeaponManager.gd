# WeaponManager.gd
# Manages active weapon inventory, switching, signal routing,
# and exposes fire, reload, and ADS inputs.
extends Node3D

signal weapon_switched(weapon_node: Node)
signal ammo_updated(current_mag: int, reserve: int)

@export var default_weapon_index: int = 0

var current_weapon: Node = null
var current_weapon_index: int = -1


func _ready() -> void:
	var count: int = get_child_count()
	if count == 0:
		return

	for i in range(count):
		var child := get_child(i)
		if child is Node3D:
			(child as Node3D).visible = false

	var start_idx: int = clampi(default_weapon_index, 0, count - 1)
	switch_to(start_idx)


func fire() -> void:
	if current_weapon != null and current_weapon.has_method("fire"):
		current_weapon.call("fire")


func reload() -> void:
	if current_weapon != null and current_weapon.has_method("reload"):
		current_weapon.call("reload")


func set_aiming(enabled: bool) -> void:
	if current_weapon != null and current_weapon.has_method("set_aiming"):
		current_weapon.call("set_aiming", enabled)


func switch_to(index: int) -> void:
	var count: int = get_child_count()
	if index < 0 or index >= count:
		return
	if current_weapon == get_child(index):
		return

	if current_weapon != null and current_weapon.is_connected("ammo_changed", _on_weapon_ammo_changed):
		current_weapon.disconnect("ammo_changed", _on_weapon_ammo_changed)

	if current_weapon != null and current_weapon is Node3D:
		(current_weapon as Node3D).visible = false

	current_weapon_index = index
	current_weapon = get_child(index)
	if current_weapon is Node3D:
		(current_weapon as Node3D).visible = true

	if current_weapon.has_signal("ammo_changed"):
		current_weapon.connect("ammo_changed", _on_weapon_ammo_changed)
		if "ammo_in_mag" in current_weapon and "reserve_ammo" in current_weapon:
			ammo_updated.emit(current_weapon.get("ammo_in_mag"), current_weapon.get("reserve_ammo"))

	weapon_switched.emit(current_weapon)


func next_weapon() -> void:
	var total: int = get_child_count()
	if total <= 1:
		return
	var next_idx: int = (current_weapon_index + 1) % total
	switch_to(next_idx)


func previous_weapon() -> void:
	var total: int = get_child_count()
	if total <= 1:
		return
	var prev_idx: int = (current_weapon_index - 1 + total) % total
	switch_to(prev_idx)


func _on_weapon_ammo_changed(current_mag: int, reserve: int) -> void:
	ammo_updated.emit(current_mag, reserve)

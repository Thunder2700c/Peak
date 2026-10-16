extends StaticBody3D

@export var crate_color: Color = Color(0.55, 0.36, 0.18)

var _material: StandardMaterial3D = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var health: Node = $HealthComponent
@onready var break_sound: AudioStreamPlayer3D = get_node_or_null("BreakSound") as AudioStreamPlayer3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = crate_color
	mesh_instance.material_override = _material
	health.connect("health_changed", Callable(self, "_on_health_changed"))
	health.connect("on_death", Callable(self, "_on_death"))


func _on_health_changed(_current: float, _maximum: float) -> void:
	# Quick white flash when hit
	_material.albedo_color = Color(1.0, 1.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(_material, "albedo_color", crate_color, 0.15)


func _on_death() -> void:
	_spawn_splinters()
	if break_sound != null and break_sound.stream != null:
		# Hide the crate, let the sound finish, then remove it
		mesh_instance.visible = false
		collision_layer = 0
		break_sound.finished.connect(queue_free)
		break_sound.play()
	else:
		queue_free()


func _spawn_splinters() -> void:
	var particles := CPUParticles3D.new()
	var piece := BoxMesh.new()
	piece.size = Vector3(0.12, 0.05, 0.05)
	var piece_material := StandardMaterial3D.new()
	piece_material.albedo_color = crate_color
	piece.material = piece_material
	particles.mesh = piece
	particles.amount = 24
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	get_tree().create_timer(2.0).timeout.connect(particles.queue_free)

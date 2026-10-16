extends WorldEnvironment
# Builds a bright daytime environment at startup, tunes the sun and colours the level.

@export_group("Sky")
@export var sky_top: Color = Color(0.25, 0.48, 0.85)
@export var sky_horizon: Color = Color(0.66, 0.78, 0.9)
@export var ground_horizon: Color = Color(0.66, 0.78, 0.9)
@export var ground_bottom: Color = Color(0.25, 0.3, 0.28)

@export_group("Atmosphere")
@export var fog_density: float = 0.0015
@export var glow_amount: float = 0.5
@export var use_ssao: bool = false

@export_group("Sun")
@export var sun_color: Color = Color(1.0, 0.95, 0.86)
@export var sun_energy: float = 1.3
@export var sun_rotation_degrees: Vector3 = Vector3(-48.0, 35.0, 0.0)
@export var sun_shadows: bool = true

@export_group("Level colours")
@export var paint_level: bool = true
@export var grass_color: Color = Color(0.30, 0.45, 0.22)
@export var wall_color: Color = Color(0.68, 0.65, 0.60)
@export var box_color: Color = Color(0.50, 0.42, 0.34)
@export var door_color: Color = Color(0.42, 0.28, 0.15)


func _ready() -> void:
	_build_environment()
	_setup_sun()
	if paint_level:
		_paint_level()


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = sky_top
	sky_material.sky_horizon_color = sky_horizon
	sky_material.ground_horizon_color = ground_horizon
	sky_material.ground_bottom_color = ground_bottom
	sky_material.sun_angle_max = 30.0

	var new_sky := Sky.new()
	new_sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = new_sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = glow_amount
	env.fog_enabled = true
	env.fog_light_color = sky_horizon
	env.fog_density = fog_density
	env.fog_aerial_perspective = 0.5
	env.ssao_enabled = use_ssao
	environment = env


func _setup_sun() -> void:
	var sun := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun == null:
		push_warning("DayEnvironment: no DirectionalLight3D found next to WorldEnvironment")
		return
	sun.visible = true
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.rotation_degrees = sun_rotation_degrees
	sun.shadow_enabled = sun_shadows
	sun.directional_shadow_max_distance = 80.0


func _paint_level() -> void:
	var level: Node = get_parent()
	_paint(level.get_node_or_null("Floor"), grass_color)
	_paint(level.get_node_or_null("Wall_L"), wall_color)
	_paint(level.get_node_or_null("Wall_R"), wall_color)
	_paint(level.get_node_or_null("Door"), door_color)
	for box_name: String in ["Box1", "Box2", "Box3", "Box4"]:
		_paint(level.get_node_or_null(box_name), box_color)


func _paint(node: Node, color: Color) -> void:
	if node == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if node is CSGPrimitive3D:
		(node as CSGPrimitive3D).material = material
	elif node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	else:
		for child in node.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = material

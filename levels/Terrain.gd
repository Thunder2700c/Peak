extends StaticBody3D
# Procedural hilly terrain: visual mesh + heightmap collision + invisible edge walls.

@export var map_size: int = 200
@export var hill_height: float = 10.0
@export var noise_frequency: float = 0.008
@export var terrain_seed: int = 7
@export var flat_radius: float = 30.0
@export var blend_distance: float = 50.0
@export var ground_material: Material = null
@export var replace_old_floor: bool = true
@export var old_floor_name: String = "Floor"
@export var edge_walls: bool = true

var _noise: FastNoiseLite = null


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = terrain_seed
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = 3

	var material: Material = _take_material_and_remove_old_floor()
	var heights: PackedFloat32Array = _make_heights()
	_build_mesh(heights, material)
	_build_collision(heights)
	if edge_walls:
		_build_edge_walls()


func _take_material_and_remove_old_floor() -> Material:
	var found: Material = ground_material
	var old_floor: Node = get_parent().get_node_or_null(old_floor_name)
	if old_floor != null:
		if found == null:
			var candidate: Variant = old_floor.get("material")
			if candidate is Material:
				found = candidate as Material
		if replace_old_floor:
			old_floor.queue_free()
	if found == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.3, 0.45, 0.22)
		found = fallback
	return found


func _height_at(x: float, z: float) -> float:
	var distance: float = Vector2(x, z).length()
	var blend: float = smoothstep(flat_radius, flat_radius + blend_distance, distance)
	return _noise.get_noise_2d(x, z) * hill_height * blend


func _make_heights() -> PackedFloat32Array:
	var samples: int = map_size + 1
	var half: float = map_size * 0.5
	var heights := PackedFloat32Array()
	heights.resize(samples * samples)
	for z in range(samples):
		for x in range(samples):
			heights[z * samples + x] = _height_at(x - half, z - half)
	return heights


func _build_mesh(heights: PackedFloat32Array, material: Material) -> void:
	var samples: int = map_size + 1
	var half: float = map_size * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(samples * samples)
	normals.resize(samples * samples)
	uvs.resize(samples * samples)

	for z in range(samples):
		for x in range(samples):
			var i: int = z * samples + x
			var wx: float = x - half
			var wz: float = z - half
			vertices[i] = Vector3(wx, heights[i], wz)
			uvs[i] = Vector2(wx, wz) * 0.25
			var left: float = heights[z * samples + maxi(x - 1, 0)]
			var right: float = heights[z * samples + mini(x + 1, samples - 1)]
			var up: float = heights[maxi(z - 1, 0) * samples + x]
			var down: float = heights[mini(z + 1, samples - 1) * samples + x]
			normals[i] = Vector3(left - right, 2.0, up - down).normalized()

	for z in range(map_size):
		for x in range(map_size):
			var a: int = z * samples + x
			var b: int = a + 1
			var c: int = a + samples
			var d: int = c + 1
			indices.append_array(PackedInt32Array([a, b, d, a, d, c]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)


func _build_collision(heights: PackedFloat32Array) -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = map_size + 1
	shape.map_depth = map_size + 1
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func _build_edge_walls() -> void:
	var half: float = map_size * 0.5
	var span: float = map_size + 4.0
	_add_wall(Vector3(half + 1.0, 20.0, 0.0), Vector3(2.0, 60.0, span))
	_add_wall(Vector3(-half - 1.0, 20.0, 0.0), Vector3(2.0, 60.0, span))
	_add_wall(Vector3(0.0, 20.0, half + 1.0), Vector3(span, 60.0, 2.0))
	_add_wall(Vector3(0.0, 20.0, -half - 1.0), Vector3(span, 60.0, 2.0))


func _add_wall(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	add_child(collision)

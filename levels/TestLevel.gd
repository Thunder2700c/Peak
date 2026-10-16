extends NavigationRegion3D
# Bakes the walkable area (terrain + props) when the game starts, on a background thread.


func _ready() -> void:
	if navigation_mesh == null:
		navigation_mesh = NavigationMesh.new()
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	navigation_mesh.cell_size = 0.5
	navigation_mesh.cell_height = 0.25
	navigation_mesh.agent_radius = 0.5
	navigation_mesh.agent_height = 2.0
	# Stricter than what the enemies can physically climb (55 degrees)
	navigation_mesh.agent_max_slope = 40.0
	navigation_mesh.agent_max_climb = 0.5
	bake_finished.connect(_on_bake_finished)
	# CSG shapes build their meshes one frame after loading, so wait a frame
	await get_tree().process_frame
	bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	print("Navigation baked. Polygons: ", navigation_mesh.get_polygon_count())

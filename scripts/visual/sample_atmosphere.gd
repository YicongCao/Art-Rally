class_name RallySampleAtmosphere
extends RefCounted

# Art-directed 16:00 look, not an astronomical simulation without location/season.
const SUN_ELEVATION_DEGREES := 24.0
const SUN_COLOR := Color("ffe0b0")
const SUN_ENERGY := 1.25
var sun_direction := Vector3.UP
var cloud_root := Node3D.new()
var near_clouds: Array[MeshInstance3D] = []
var far_clouds: Array[MeshInstance3D] = []


func build(land: RallySampleLandscape, sun: DirectionalLight3D) -> void:
	build_at(land.dressing,land.route,land.center,sun)


func build_at(parent: Node3D, route: RallyStageRoute, center: Vector3, sun: DirectionalLight3D, extent: float = 1.0) -> void:
	var forward := route.tangent_at(470)
	forward.y = 0
	forward = forward.normalized()
	var horizontal := forward.rotated(Vector3.UP, -deg_to_rad(14.0))
	var elevation := deg_to_rad(SUN_ELEVATION_DEGREES)
	sun_direction = horizontal * cos(elevation) + Vector3.UP * sin(elevation)
	apply_sun(sun)
	cloud_root.name = "WorldSpaceClouds"
	parent.add_child(cloud_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 160043
	for layer: int in range(2):
		for i: int in range(16 if layer == 0 else 22):
			var count := 16.0 if layer == 0 else 22.0
			var angle := TAU * i / count + layer * 0.13
			var distance := rng.randf_range(540, 850) if layer == 0 else rng.randf_range(1250, 1700)
			var at := center + Vector3(cos(angle) * distance, rng.randf_range(190, 290) if layer == 0 else rng.randf_range(350, 460), sin(angle) * distance)*extent
			# Leave a small opening around the actual light source for occasional flare.
			if (at - center).normalized().dot(sun_direction) > 0.97: continue
			var cloud := MeshInstance3D.new()
			cloud.name = "Cloud_%d_%d" % [layer, i]
			cloud.mesh = cloud_mesh(200 + i * 17 + layer, sun_direction, layer)
			cloud.position = at
			cloud.rotation.y = rng.randf_range(-PI, PI)
			var scale_factor := rng.randf_range(0.8, 1.3) * (1.0 if layer == 0 else 1.6)
			cloud.scale = Vector3.ONE * scale_factor * extent
			cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud_root.add_child(cloud)
			if layer == 0: near_clouds.append(cloud)
			else: far_clouds.append(cloud)


func apply_sun(sun: DirectionalLight3D) -> void:
	sun.basis = Basis.looking_at(-sun_direction, Vector3.UP)
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY


static func cloud_mesh(seed_value: int, light: Vector3, layer: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for puff: int in range(7):
		var at := Vector3((puff - 3) * 22.0, rng.randf_range(-3, 4), rng.randf_range(-15, 15))
		var width := rng.randf_range(24, 40)
		var depth := rng.randf_range(19, 32)
		var height := rng.randf_range(6, 12)
		var rings: Array[PackedVector3Array] = []
		for band: int in range(3):
			var ring := PackedVector3Array()
			for i: int in range(8):
				var angle: float = i * TAU / 8 + (0.13 if band == 2 else 0.0)
				var radius: float = [0.75, 1.0, 0.62][band]
				var y: float = [-0.15, 0.20, 0.72][band]
				ring.append(at + Vector3(cos(angle) * width * radius, y * height, sin(angle) * depth * radius))
			rings.append(ring)
		for i: int in range(8):
			var next := (i + 1) % 8
			triangle(tool, at + Vector3.DOWN * height * 0.15, rings[0][next], rings[0][i])
			triangle(tool, at + Vector3.UP * height * 0.96, rings[2][i], rings[2][next])
			for band: int in range(2):
				triangle(tool, rings[band][i], rings[band][next], rings[band + 1][i])
				triangle(tool, rings[band][next], rings[band + 1][next], rings[band + 1][i])
	tool.generate_normals()
	var result := tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/sample_cloud.gdshader")
	material.set_shader_parameter("sun_direction", light)
	material.set_shader_parameter("distant_layer", float(layer))
	result.surface_set_material(0, material)
	return result


static func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.set_smooth_group(-1)
	for point: Vector3 in [a, b, c]: tool.add_vertex(point)

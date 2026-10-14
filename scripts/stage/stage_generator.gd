class_name RallyStageGenerator
extends Node3D

@export var definition: RallyStageDefinition = preload("res://resources/stages/sunset_ridge.tres")
var route := RallyStageRoute.new()
var chunk_bodies: Array[StaticBody3D] = []
var decoration_positions := PackedVector3Array()


func _ready() -> void:
	build()


func build() -> void:
	route.build(definition)
	var errors := route.validate()
	if not errors.is_empty():
		push_error("Invalid stage: %s" % errors)
		return
	for start: int in range(0, route.points.size() - 1, 20):
		_build_chunk(start, mini(start + 20, route.points.size() - 1))
	_build_markers()


func surface_at(point: Vector3, hint: int = -1) -> RallySurfaceSample:
	var p := route.project(to_local(point), hint)
	var id := definition.surface_id(p.s) if absf(p.lateral) <= route.width_at(p.s) * 0.5 else 3
	return RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[id], definition.water_depth(p.s, p.lateral) if id != 3 else 0.0)


func vertex_at(index: int, column: int) -> Vector3:
	var s := route.distances[index]
	var half := route.width_at(s) * 0.5
	var offsets := PackedFloat64Array([-22, -12, -half - 1.2, -half, 0, half, half + 1.2, 12, 22])
	var lateral := offsets[column]
	var point := route.points[index] + route.rights[index] * lateral
	if column < 3 or column > 5:
		var edge_distance := absf(lateral) - half
		point.y -= minf(edge_distance * 0.18, 2.3)
		point.y += smoothstep(1.5, 10, edge_distance) * 0.5 * sin(s * 0.03 + lateral * 0.2)
	return point


func _build_chunk(start: int, end: int) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(start, end):
		for col: int in range(8):
			var color := RallySurfaceQuery.PROFILES[definition.surface_id(route.distances[i])].color if col in [3, 4] else Color("59633a")
			if col in [2, 5]: color = Color("73664b")
			var a := vertex_at(i, col)
			var b := vertex_at(i + 1, col)
			var c := vertex_at(i, col + 1)
			var d := vertex_at(i + 1, col + 1)
			for vertex: Vector3 in [a, b, c, c, b, d]:
				tool.set_color(color)
				tool.add_vertex(vertex)
	tool.generate_normals()
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	add_child(visual)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("surface_provider", self)
	body.set_meta("surface_hint", (start + end) / 2)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)
	chunk_bodies.append(body)
	_build_water(start, end)


func _build_water(start: int, end: int) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := 0
	for i: int in range(start, end):
		if definition.water_depth(route.distances[i] + 1, 0) <= 0: continue
		var a := route.points[i] - route.rights[i] * 2.65 + Vector3.UP * 0.025
		var b := route.points[i + 1] - route.rights[i + 1] * 2.65 + Vector3.UP * 0.025
		var c := route.points[i] + route.rights[i] * 2.65 + Vector3.UP * 0.025
		var d := route.points[i + 1] + route.rights[i + 1] * 2.65 + Vector3.UP * 0.025
		for vertex: Vector3 in [a, b, c, c, b, d]: tool.add_vertex(vertex)
		vertices += 6
	if vertices == 0: return
	tool.generate_normals()
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("517f89")
	material.roughness = 0.16
	material.metallic = 0.35
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	add_child(visual)


func _build_markers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = definition.seed_value
	for s: int in range(20, int(route.length), 25):
		var index := route.index_at(s)
		for side: float in [-1, 1]:
			var point := route.position_at(s) + route.rights[index] * side * (route.width_at(s) * 0.5 + 0.5)
			point.y += 0.25
			GrayboxGeometry.box(self, "RoadMarker", Vector3(0.13, 0.65, 0.13), point, Color("e2d9b1"))
		if s % 100 == 20:
			var position := route.position_at(s) + route.rights[index] * rng.randf_range(10, 17)
			position.y -= 1
			decoration_positions.append(position)
			GrayboxGeometry.box(self, "Landmark", Vector3(2, rng.randf_range(2, 5), 2), position, Color("424d38"))
	for s: float in [20, route.length - 30]:
		var at := route.position_at(s)
		var right := route.rights[route.index_at(s)]
		for side: float in [-1, 1]:
			GrayboxGeometry.box(self, "GatePost", Vector3(0.3, 3.4, 0.3), at + right * side * 4 + Vector3.UP * 1.7, Color("d99442"))
		GrayboxGeometry.label(self, "START" if s == 20 else "FINISH", at + Vector3.UP * 3.5)

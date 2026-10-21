class_name RallyStageGenerator
extends Node3D

@export var definition: RallyStageDefinition = preload("res://resources/stages/sunset_ridge.tres")
const SHOULDER_WIDTH := 1.2
var auto_build: bool = true
var route := RallyStageRoute.new()
var chunk_bodies: Array[StaticBody3D] = []
var decoration_positions := PackedVector3Array()
var road_visuals: Array[MeshInstance3D] = []
var water_visuals: Array[MeshInstance3D] = []


func _ready() -> void:
	if auto_build: build()


func build() -> void:
	route.build(definition)
	var errors := route.validate()
	if not errors.is_empty():
		push_error("Invalid stage: %s" % errors)
		return
	for start: int in range(0, route.points.size() - 1, 20):
		_build_chunk(start, mini(start + 20, route.points.size() - 1))
	_build_markers()
	_build_culvert()
	_build_runout()


func _build_culvert() -> void:
	for station: float in definition.culverts:
		var pose := route.pose_at(station, 0)
		for side: float in [-1, 1]:
			GrayboxGeometry.box(self, "CulvertWing", Vector3(1.0, 0.5, 3.0), pose * Vector3(side * 4.3, -0.35, 0), Color("686d64"), false, pose.basis.get_euler() * 180 / PI)
			GrayboxGeometry.box(self, "DrainOpening", Vector3(0.04, 0.35, 1.1), pose * Vector3(side * 4.85, -0.35, 0), Color("25302a"), false, pose.basis.get_euler() * 180 / PI)

func _build_runout() -> void:
	# A long braking apron lies beyond the timed finish; the result remains frozen there.
	var pose := route.pose_at(route.length, 0)
	var forward := -pose.basis.z
	var center := pose.origin + forward * 70 - pose.basis.y * 0.5
	var body := GrayboxGeometry.box(self, "FinishApron", Vector3(16, 1, 145), center, RallySurfaceQuery.PROFILES[definition.surface_id(route.length)].color, true, pose.basis.get_euler() * 180 / PI)
	body.set_meta("surface_id", definition.surface_id(route.length))


func surface_at(point: Vector3, hint: int = -1) -> RallySurfaceSample:
	var p := route.project(to_local(point), hint, 14)
	return _surface_at_coordinates(p.s, p.lateral)


func surface_footprint(point: Vector3, forward: Vector3, right: Vector3, hint: int) -> RallySurfaceSample:
	var p := route.project(to_local(point), hint, 14)
	var local_basis := global_basis.inverse()
	var tangent := route.tangents[p.index]
	var across := route.rights[p.index]
	var samples: Array[RallySurfaceSample] = [_surface_at_coordinates(p.s, p.lateral)]
	# One road projection per wheel; patch offsets are tiny relative to the road curvature.
	for offset: Vector3 in [forward * 0.12, -forward * 0.12, right * 0.09, -right * 0.09]:
		var local := local_basis * offset
		samples.append(_surface_at_coordinates(p.s + local.dot(tangent), p.lateral + local.dot(across)))
	return RallySurfaceSample.average(samples)


func _surface_at_coordinates(s: float, lateral: float) -> RallySurfaceSample:
	var half := route.width_at(s)*.5
	var lane_lateral := clampf(lateral,-half,half)
	var depth := definition.water_depth(s,lane_lateral)
	var weights := definition.surface_distribution(s,lane_lateral)
	var samples: Array[RallySurfaceSample] = []
	var amounts := PackedFloat64Array()
	for surface: int in range(weights.size()):
		if weights[surface]>.0001:
			samples.append(RallySurfaceQuery.road_sample(surface,depth))
			amounts.append(weights[surface])
	var road := samples[0] if samples.size()==1 else RallySurfaceSample.weighted_average(samples,amounts)
	var outside := absf(lateral)-half
	if outside<=0: return road
	var grass := RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[definition.shoulder_surface])
	# Compacted shoulder occupies the same 1.2m strip as the visible earth edge.
	# No discontinuity at either edge, including narrow and muddy sections.
	var blend := smoothstep(0,SHOULDER_WIDTH,outside)
	return RallySurfaceSample.weighted_average([road,grass],PackedFloat64Array([1.0-blend,blend]))


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
	point.y += route.road_relief(s,lateral)
	for river: Vector3 in definition.river_crossings:
		if absf(s-river.x)<river.y*.5+5 and absf(lateral)>half+1.1:
			point.y-=3.5*(1-smoothstep(river.y*.5,river.y*.5+5,absf(s-river.x)))*smoothstep(half+1.1,half+4,absf(lateral))
	return point


func _build_chunk(start: int, end: int) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(start, end):
		for col: int in range(8):
			if absf(definition.mountain_side_at(route.distances[i]))>.01 and col in [0,1,6,7]: continue
			for corner: Vector2i in [Vector2i(i,col),Vector2i(i+1,col),Vector2i(i,col+1),Vector2i(i,col+1),Vector2i(i+1,col),Vector2i(i+1,col+1)]:
				var vertex := vertex_at(corner.x,corner.y)
				tool.set_uv(Vector2((vertex-route.points[corner.x]).dot(route.rights[corner.x]),route.distances[corner.x]))
				tool.set_uv2(Vector2(route.width_at(route.distances[corner.x])*0.5,definition.surface_id(route.distances[corner.x])))
				var station := route.distances[corner.x]
				var lateral := (vertex_at(corner.x,corner.y)-route.points[corner.x]).dot(route.rights[corner.x])
				var weights := definition.surface_weights(station,lateral)
				tool.set_color(Color(weights.x,weights.y,weights.z,definition.wetness(station,lateral)))
				tool.add_vertex(vertex)
	tool.generate_normals()
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	road_visuals.append(visual)
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
		for index: int in range(6):
			var row := i+1 if index in [1,4,5] else i
			tool.set_uv(Vector2(-2.65 if index in [0,1,4] else 2.65,route.distances[row]))
			for pool: Vector3 in definition.water_sections:
				if route.distances[i]+1>pool.x and route.distances[i]+1<pool.y: tool.set_uv2(Vector2(pool.x,pool.y))
			tool.add_vertex([a,b,c,c,b,d][index])
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
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	water_visuals.append(visual)


func _build_markers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = definition.seed_value
	var marker_transforms: Array[Transform3D] = []
	for s: int in range(20, int(route.length), 25):
		var index := route.index_at(s)
		for side: float in [-1, 1]:
			var point := route.position_at(s) + route.rights[index] * side * (route.width_at(s) * 0.5 + 0.5)
			point.y += 0.25
			if not RallyBreakablePosts.covers(s,route.length):
				marker_transforms.append(Transform3D(Basis.IDENTITY,point))
		if s % 100 == 20:
			var position := route.position_at(s) + route.rights[index] * rng.randf_range(10, 17)
			position.y -= 1
			decoration_positions.append(position)
			var prototype := GrayboxGeometry.box(self, "Landmark", Vector3(2, rng.randf_range(2, 5), 2), position, Color("424d38"))
			prototype.set_meta("prototype_marker", true)
	for s: float in [20, route.length - 30]:
		var at := route.position_at(s)
		var right := route.rights[route.index_at(s)]
		for side: float in [-1, 1]:
			GrayboxGeometry.box(self, "GatePost", Vector3(0.3, 3.4, 0.3), at + right * side * 4 + Vector3.UP * 1.7, Color("d99442"))
	_build_marker_batch(marker_transforms)


func _build_marker_batch(transforms: Array[Transform3D]) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.13,0.65,0.13)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e2d9b1")
	material.roughness = 0.95
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i: int in range(transforms.size()): multimesh.set_instance_transform(i,transforms[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = "RoadMarkers"
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


func build_incremental(progress: Callable) -> void:
	route.build(definition)
	assert(route.validate().is_empty())
	var count := route.points.size()-1
	for start: int in range(0,count,20):
		_build_chunk(start,mini(start+20,count))
		if start%200==0:
			progress.call(0.1+0.55*float(start)/count,"铺设道路与碰撞")
			await get_tree().process_frame
	_build_markers()
	_build_culvert()
	_build_runout()


func surface_position_at(s: float,lateral: float) -> Vector3:
	# Same barycentric interpolation as the road triangles. Decorations follow
	# the rendered/colliding surface, including bumps and banking.
	var i := route.index_at(s)
	var half := route.width_at(s)*.5
	var offsets := PackedFloat64Array([-22,-12,-half-1.2,-half,0,half,half+1.2,12,22])
	var column := 0
	while column<7 and lateral>offsets[column+1]: column+=1
	var u := clampf((s-route.distances[i])/route.spacing,0,1)
	var v := clampf((lateral-offsets[column])/(offsets[column+1]-offsets[column]),0,1)
	var a := vertex_at(i,column)
	var b := vertex_at(i+1,column)
	var c := vertex_at(i,column+1)
	var d := vertex_at(i+1,column+1)
	if u+v<=1: return a*(1-u-v)+b*u+c*v
	return c*(1-u)+b*(1-v)+d*(u+v-1)

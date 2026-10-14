class_name RallySampleLandscape
extends RallyStageGenerator

const START := 430.0
const END := 630.0
const BUFFER_START := 400.0
const BUFFER_END := 700.0
var dressing := Node3D.new()
var road_visuals: Array[MeshInstance3D] = []
var styled_material: ShaderMaterial
var original_material: StandardMaterial3D
var terrain_noise := FastNoiseLite.new()
var center := Vector3.ZERO
var style_enabled: bool = true
var terrain_mesh: MeshInstance3D
var terrain_bounds := AABB()


func build() -> void:
	name = "Landscape"
	route.build(definition)
	center = route.position_at((START + END) * 0.5)
	terrain_noise.seed = 593
	terrain_noise.frequency = 0.006
	terrain_noise.fractal_octaves = 4
	styled_material = ShaderMaterial.new()
	styled_material.shader = preload("res://assets/shaders/sample_ground.gdshader")
	styled_material.set_shader_parameter("road_mesh", true)
	original_material = StandardMaterial3D.new()
	original_material.vertex_color_use_as_albedo = true
	original_material.roughness = 0.95
	dressing.name = "VisualOnly"
	add_child(dressing)
	var first := route.index_at(BUFFER_START)
	var last := route.index_at(BUFFER_END)
	for begin: int in range(first, last, 20):
		_build_sample_chunk(begin, mini(begin + 20, last))
	_build_terrain()
	_build_mountains()


func _build_sample_chunk(begin: int, end: int) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(begin, end):
		for col: int in range(8):
			for corner: Vector2i in [Vector2i(i,col),Vector2i(i+1,col),Vector2i(i,col+1),Vector2i(i,col+1),Vector2i(i+1,col),Vector2i(i+1,col+1)]:
				var point := vertex_at(corner.x, corner.y)
				var lateral := (point - route.points[corner.x]).dot(route.rights[corner.x])
				tool.set_uv(Vector2(lateral, route.distances[corner.x]))
				tool.set_color(RallySurfaceQuery.PROFILES[1].color if col in [3,4] else Color("59633a"))
				tool.add_vertex(point)
	tool.generate_normals()
	var mesh := tool.commit()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = styled_material
	add_child(visual)
	road_visuals.append(visual)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("surface_provider", self)
	body.set_meta("surface_hint", (begin + end) / 2)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)
	chunk_bodies.append(body)


func nearby(point: Vector3) -> Dictionary:
	# Horizontal projection keeps distant terrain above/below road from moving its anchor.
	var best := INF
	var result := {"s": START, "lateral": 0.0, "point": center, "distance": INF}
	for i: int in range(route.index_at(BUFFER_START), route.index_at(BUFFER_END), 4):
		var a := route.points[i]
		var b := route.points[mini(i+4, route.points.size()-1)]
		var delta := Vector2(b.x-a.x,b.z-a.z)
		var t := clampf(Vector2(point.x-a.x,point.z-a.z).dot(delta)/delta.length_squared(),0,1)
		var at := a.lerp(b,t)
		var distance := Vector2(point.x-at.x,point.z-at.z).length_squared()
		if distance < best:
			best = distance
			result = {"s": lerpf(route.distances[i],route.distances[mini(i+4,route.points.size()-1)],t), "lateral": (point-at).dot(route.rights[i]), "point": at, "distance": sqrt(distance)}
	return result


func ground_height(x: float, z: float) -> float:
	var p := nearby(Vector3(x,0,z))
	var distance: float = p.distance
	var side: float = signf(p.lateral)
	var close_height: float = p.point.y - minf(maxf(0,distance-2.8)*0.18,2.3)
	close_height += smoothstep(1.5,10,distance-2.8)*0.5*sin(float(p.s)*0.03+float(p.lateral)*0.2)
	var hills := center.y - 8.0 + terrain_noise.get_noise_2d(x,z)*55.0 + side * minf(distance*0.18,32)
	return lerpf(close_height-0.11,hills,smoothstep(21,100,distance))


func ground_at(s: float, lateral: float) -> Vector3:
	var point := route.position_at(s)+route.rights[route.index_at(s)]*lateral
	if absf(lateral) < 21:
		point.y -= minf(maxf(0,absf(lateral)-2.8)*0.18,2.3)
		point.y += smoothstep(1.5,10,absf(lateral)-2.8)*0.5*sin(s*0.03+lateral*0.2)
	else:
		point.y = ground_height(point.x,point.z)
	return point


func _build_terrain() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 480.0
	var step_size := 8.0
	for x: int in range(120):
		for z: int in range(120):
			for corner: Vector2i in [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]:
				var px := center.x-half+corner.x*step_size
				var pz := center.z-half+corner.y*step_size
				tool.set_color(Color.WHITE)
				tool.add_vertex(Vector3(px,ground_height(px,pz)-0.3,pz))
	tool.generate_normals()
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.name = "SurroundingTerrain"
	terrain_mesh.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/sample_ground.gdshader")
	terrain_mesh.material_override = material
	dressing.add_child(terrain_mesh)
	terrain_bounds = terrain_mesh.mesh.get_aabb()


func _build_mountains() -> void:
	for ring: int in range(3):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var radius := 580.0+ring*380.0
		for i: int in range(96):
			var a := TAU*i/96.0
			var b := TAU*(i+1)/96.0
			var height_a := 90+55*sin(a*5+ring)+35*sin(a*9+2)+ring*22
			var height_b := 90+55*sin(b*5+ring)+35*sin(b*9+2)+ring*22
			var near_a := center+Vector3(cos(a)*radius,-40,sin(a)*radius)
			var near_b := center+Vector3(cos(b)*radius,-40,sin(b)*radius)
			var peak_a := center+Vector3(cos(a)*(radius+160),height_a,sin(a)*(radius+160))
			var peak_b := center+Vector3(cos(b)*(radius+160),height_b,sin(b)*(radius+160))
			var far_a := center+Vector3(cos(a)*(radius+380),-40,sin(a)*(radius+380))
			var far_b := center+Vector3(cos(b)*(radius+380),-40,sin(b)*(radius+380))
			for vertex: Vector3 in [near_a,peak_b,near_b,near_a,peak_a,peak_b,peak_a,far_a,far_b,peak_a,far_b,peak_b]:
				tool.set_color(Color("67796d").lerp(Color("9cbbc5"),ring*0.32).darkened(0.08*sin(a*13)))
				tool.add_vertex(vertex)
		tool.generate_normals()
		var mountain := MeshInstance3D.new()
		mountain.name = "MountainLayer%d" % ring
		mountain.mesh = tool.commit()
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mountain.material_override = material
		dressing.add_child(mountain)


func set_style(enabled: bool) -> void:
	style_enabled = enabled
	dressing.visible = enabled
	for visual: MeshInstance3D in road_visuals:
		visual.material_override = styled_material if enabled else original_material

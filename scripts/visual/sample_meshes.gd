class_name RallySampleMeshes
extends RefCounted

var tool := SurfaceTool.new()


func _init() -> void:
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)


func append(mesh: Mesh, transform: Transform3D, color: Color) -> void:
	var data := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	for index: int in indices:
		tool.set_color(color.srgb_to_linear())
		tool.set_smooth_group(-1)
		tool.add_vertex(transform*vertices[index])


func box(size: Vector3, position: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	append(mesh,Transform3D(Basis.from_euler(rotation),position),color)


func cone(bottom: float, top: float, height: float, position: Vector3, color: Color, segments: int = 8) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	append(mesh,Transform3D(Basis.IDENTITY,position),color)


func ellipsoid(size: Vector3, position: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 8
	mesh.rings = 3
	append(mesh,Transform3D(Basis.from_euler(rotation).scaled(size),position),color)


func beam(a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius*0.65
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	var up := (b-a).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01: right = Vector3.RIGHT
	append(mesh,Transform3D(Basis(right,up,right.cross(up)),(a+b)*0.5),color)


func finish() -> ArrayMesh:
	tool.generate_normals()
	var mesh := tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/screenprint_environment.gdshader")
	mesh.surface_set_material(0,material)
	return mesh


# Shared geometry stays inside the existing tree clearance envelope. The named
# "umbrella" placement now carries an autumn broadleaf crown, keeping placement
# seeds and collision bodies stable while changing the visual silhouette.
static func pine(seed_value: int, umbrella: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var builder := RallySampleMeshes.new()
	var bark := Color("78717c") if umbrella else Color("685047")
	builder.cone(0.19,0.045,7.4,Vector3(0,3.7,0),bark,7)
	if umbrella:
		var palette: Array[Color] = [Color("e96526"),Color("efb52d"),Color("ce3628")]
		var crown_color := palette[posmod(seed_value / 19,3)]
		for i: int in range(16):
			var angle := i*2.39996
			var radius := rng.randf_range(0.6,1.55)
			var at := Vector3(cos(angle)*radius,rng.randf_range(4.8,7.3),sin(angle)*radius)
			builder.beam(Vector3(0,2.7+i*0.16,0),at,0.065,bark)
			# Small, intersecting opaque leaves give the crown a broken edge without
			# alpha overdraw or camera-facing billboards.
			for leaf: int in range(34):
				var offset := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.85,0.85),rng.randf_range(-1,1))
				if offset.length_squared()>1.25: offset *= 0.65
				var center := at+offset
				var rotation := Basis.from_euler(Vector3(rng.randf_range(-1.1,1.1),rng.randf()*TAU,rng.randf_range(-0.8,0.8)))
				var across := rotation*Vector3(rng.randf_range(0.23,0.36),0,0)
				var up := rotation*Vector3(0,rng.randf_range(0.28,0.42),0)
				var color := crown_color.darkened(rng.randf_range(0,0.22)).lightened(rng.randf_range(0,0.10))
				builder.round_leaf(center,across,up,color)
	else:
		var palette: Array[Color] = [Color("177363"),Color("195b65"),Color("bea740")]
		var needles := palette[posmod(seed_value / 39,3)]
		for tier: int in range(18):
			var y := 1.5+tier*0.36
			var radius := (2.1-tier*0.108)*rng.randf_range(0.88,1.08)
			for branch: int in range(7):
				var angle := branch*TAU/7+tier*1.31
				var outward := Vector3(cos(angle),0,sin(angle))
				var side := Vector3(-sin(angle),0,cos(angle))
				var start := Vector3(0,y+0.30,0)
				var color := needles.lightened(rng.randf_range(0,0.12)).darkened(rng.randf_range(0,0.12))
				# Serrated branch fans replace stacked solid cones. Each fan has a
				# raised spine and drooping, alternating needle tips.
				for segment: int in range(5):
					var t0 := segment/5.0
					var t1 := (segment+1)/5.0
					var c0 := start+outward*radius*t0-Vector3.UP*t0*t0*0.72
					var c1 := start+outward*radius*t1-Vector3.UP*t1*t1*0.72
					var width := radius*0.46*(1.0-t0)
					for sign_value: float in [-1,1]:
						var tooth := c0+side*width*sign_value+outward*radius*0.20-Vector3.UP*0.13
						var next_edge := c1+side*radius*0.34*(1.0-t1)*sign_value-Vector3.UP*0.10
						builder.triangle(c0,tooth,c1,color)
						builder.triangle(tooth,next_edge,c1,color.darkened(0.04))
		builder.cone(0.27,0,1.15,Vector3(0,8.0,0),needles,7)
	var mesh := builder.finish()
	mesh.surface_set_material(0,foliage_material(false))
	return mesh


func triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	tool.set_color(color.srgb_to_linear())
	tool.set_smooth_group(-1)
	for point: Vector3 in [a,b,c]: tool.add_vertex(point)


func leaf(center: Vector3,across: Vector3,up: Vector3,color: Color) -> void:
	triangle(center-up,center-across,center+up,color)
	triangle(center-up,center+up,center+across,color.lightened(0.04))


func round_leaf(center: Vector3,across: Vector3,up: Vector3,color: Color) -> void:
	# Six broad facets form a soft organic silhouette rather than a diamond shard.
	var points := [center-up,center-up*.5-across*.88,center+up*.5-across*.88,center+up,center+up*.5+across*.88,center-up*.5+across*.88]
	var spine := center+across.cross(up).normalized()*.065
	for i: int in range(6): triangle(spine,points[i],points[(i+1)%6],color)


static func foliage_material(grass_blades: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/autumn_foliage.gdshader")
	material.set_shader_parameter("grass_blades",grass_blades)
	return material


static func tree_shadow(umbrella: bool) -> ArrayMesh:
	var builder := RallySampleMeshes.new()
	builder.cone(0.22,0.08,6.2,Vector3(0,3.1,0),Color.WHITE,5)
	if umbrella:
		builder.cone(2.2,1.35,1.5,Vector3(0,5.7,0),Color.WHITE,7)
	else:
		builder.cone(2.0,0.10,4.8,Vector3(0,4.0,0),Color.WHITE,7)
	return builder.finish()


static func rock(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var builder := RallySampleMeshes.new()
	builder.ellipsoid(Vector3(1,0.8,0.9),Vector3(0,0.45,0),Color("929eaa"),Vector3(0.2,rng.randf()*TAU,0.25))
	builder.ellipsoid(Vector3(0.7,0.55,0.7),Vector3(0.55,0.25,0.1),Color("aab3bd"),Vector3(0.3,0.7,0.15))
	return builder.finish()


static func shrub(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var builder := RallySampleMeshes.new()
	var palette: Array[Color] = [Color("bd6444"),Color("b7a443"),Color("698460")]
	var color := palette[posmod(seed_value,3)]
	for i: int in range(90):
		var angle := rng.randf()*TAU
		var at := Vector3(cos(angle)*rng.randf_range(0.1,0.55),rng.randf_range(0.2,0.85),sin(angle)*rng.randf_range(0.1,0.55))
		builder.leaf(at,Vector3(cos(angle)*0.10,0,sin(angle)*0.10),Vector3(0,0.14,0),color.darkened(rng.randf_range(0,0.2)))
	var mesh := builder.finish()
	mesh.surface_set_material(0,foliage_material(false))
	return mesh


static func grass(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var builder := RallySampleMeshes.new()
	for i: int in range(32):
		var a := rng.randf()*TAU
		var base := Vector3(cos(a),0,sin(a))*rng.randf_range(0.02,0.82)
		var across := Vector3(-sin(a),0,cos(a))*rng.randf_range(0.018,0.035)
		var tip := base+Vector3(cos(a)*0.20,rng.randf_range(0.32,0.78),sin(a)*0.20)
		var middle := base.lerp(tip,0.6)+Vector3.UP*0.04
		var shade := rng.randf_range(0,0.13)
		for v: Vector3 in [base-across,middle+across,middle-across,base-across,base+across,middle+across,middle-across,middle+across,tip]:
			var color := Color("a98236").lerp(Color("d9b956"),clampf(v.y/0.55,0,1)).darkened(shade)
			builder.tool.set_color(color.srgb_to_linear())
			builder.tool.add_vertex(v)
	var mesh := builder.finish()
	mesh.surface_set_material(0,foliage_material(true))
	return mesh

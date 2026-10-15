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
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,material)
	return mesh


static func pine(seed_value: int, umbrella: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var builder := RallySampleMeshes.new()
	var bark := Color("685440")
	builder.cone(0.21,0.08,6.2,Vector3(0,3.1,0),bark)
	if umbrella:
		for i: int in range(8):
			var a := i*TAU/8+0.3
			var at := Vector3(cos(a)*rng.randf_range(0.7,1.8),rng.randf_range(4.5,6.0),sin(a)*rng.randf_range(0.7,1.8))
			builder.beam(Vector3(0,3.2,0),at,0.10,bark)
			builder.ellipsoid(Vector3(rng.randf_range(1.0,1.6),0.7,rng.randf_range(0.9,1.6)),at,Color("3b5533").lightened(rng.randf_range(0,0.13)))
		builder.ellipsoid(Vector3(1.7,0.85,1.5),Vector3(0,6.3,0),Color("52633a"))
	else:
		for i: int in range(6):
			var y := 2.0+i*0.82
			var radius := 1.9-i*0.25
			var offset := Vector3(rng.randf_range(-0.18,0.18),y,rng.randf_range(-0.18,0.18))
			builder.cone(radius,0.07,2.3-i*0.12,offset,Color("254638").lightened(rng.randf_range(0.0,0.09)),9)
	return builder.finish()


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
	builder.ellipsoid(Vector3(1,0.8,0.9),Vector3(0,0.45,0),Color("86836c"),Vector3(0.2,rng.randf()*TAU,0.25))
	builder.ellipsoid(Vector3(0.7,0.55,0.7),Vector3(0.55,0.25,0.1),Color("999079"),Vector3(0.3,0.7,0.15))
	return builder.finish()


static func shrub(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var builder := RallySampleMeshes.new()
	for i: int in range(5):
		builder.ellipsoid(Vector3(0.5,0.42,0.45),Vector3(rng.randf_range(-0.4,0.4),rng.randf_range(0.3,0.65),rng.randf_range(-0.4,0.4)),Color("626d37").darkened(rng.randf_range(0,0.25)))
	return builder.finish()


static func grass(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var builder := RallySampleMeshes.new()
	for i: int in range(9):
		var a := rng.randf()*TAU
		var base := Vector3(cos(a),0,sin(a))*rng.randf_range(0.02,0.22)
		var across := Vector3(-sin(a),0,cos(a))*0.045
		var tip := base+Vector3(cos(a)*0.22,rng.randf_range(0.22,0.60),sin(a)*0.22)
		var middle := base.lerp(tip,0.6)+Vector3.UP*0.05
		for v: Vector3 in [base-across,middle+across,middle-across,base-across,base+across,middle+across,middle-across,middle+across,tip]:
			builder.tool.set_color(Color("a2a064").lerp(Color("576335"),rng.randf()).srgb_to_linear())
			builder.tool.add_vertex(v)
	return builder.finish()

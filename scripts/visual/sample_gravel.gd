class_name RallySampleGravel
extends RefCounted

var root := Node3D.new()
var placements: Array[Dictionary] = []
var batches: Array[MultiMeshInstance3D] = []


func build(land: RallySampleLandscape) -> void:
	root.name = "SurfaceAggregate"
	land.dressing.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 164307
	var transforms: Dictionary = {}
	var colors: Dictionary = {}
	for i: int in range(14500):
		var station := rng.randf_range(land.START,land.END)
		var lateral := rng.randf_range(-2.75,2.75)
		# The wheel paths are more compacted; loose aggregate gathers near edges/center.
		if absf(absf(lateral)-0.8) < 0.28 and rng.randf() < 0.75: continue
		var radius := rng.randf_range(0.025,0.055)
		var height := rng.randf_range(0.004,0.014)
		var index := land.route.index_at(station)
		var fraction := (station-land.route.distances[index])/(land.route.distances[index+1]-land.route.distances[index])
		var right := land.route.rights[index].lerp(land.route.rights[index+1],fraction)
		var point := land.route.position_at(station)+right*lateral
		var up := land.route.pose_at(station).basis.y
		point += up*0.0008
		var basis := land.route.pose_at(station).basis * Basis(Vector3.UP,rng.randf()*TAU)
		basis = basis.scaled_local(Vector3(radius,height,radius*rng.randf_range(0.65,1.4)))
		var key := int((station-land.START)/20)
		if not transforms.has(key):
			transforms[key] = []
			colors[key] = []
		transforms[key].append(Transform3D(basis,point))
		colors[key].append(Color.WHITE.darkened(rng.randf_range(0,0.3)))
		placements.append({"s":station,"lateral":lateral,"height":height,"radius":radius,"point":point})
	var mesh := pebble_mesh()
	for key: int in transforms:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = transforms[key].size()
		for i: int in range(multimesh.instance_count):
			multimesh.set_instance_transform(i,transforms[key][i])
			multimesh.set_instance_color(i,colors[key][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "GravelPatch_%d"%key
		instance.multimesh = multimesh
		instance.visibility_range_end = 70
		instance.visibility_range_end_margin = 15
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
		batches.append(instance)


static func pebble_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.14,1,0.03)
	for i: int in range(6):
		var a := TAU*i/6.0
		var b := TAU*(i+1)/6.0
		for vertex: Vector3 in [Vector3(cos(a),0,sin(a)),top,Vector3(cos(b),0,sin(b))]:
			tool.set_color(Color("b7a588").darkened(0.06*(i%3)).srgb_to_linear())
			tool.set_smooth_group(-1)
			tool.add_vertex(vertex)
	tool.generate_normals()
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,material)
	return mesh

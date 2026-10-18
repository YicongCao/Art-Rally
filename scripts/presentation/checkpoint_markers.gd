class_name RallyCheckpointMarkers
extends RefCounted

var materials: Array[ShaderMaterial] = []
var symbols: Array[Sprite3D] = []
var root := Node3D.new()
var last_gate: int = -1
var tube_multimesh := MultiMesh.new()


func build(parent: Node3D,route: RallyStageRoute,gates: PackedFloat64Array) -> void:
	root.name = "InflatableCheckpoints"
	parent.add_child(root)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/checkpoint_air.gdshader")
	var tube_transforms: Array[Transform3D] = []
	var blower_transforms: Array[Transform3D] = []
	for i: int in range(gates.size()):
		var pose := route.pose_at(gates[i],0)
		materials.append(material)
		for side: float in [-1,1]:
			var anchor := pose.origin+pose.basis.x*side*(route.width_at(gates[i])*0.5+0.85)-Vector3.UP*0.15
			blower_transforms.append(Transform3D(Basis.IDENTITY,anchor+Vector3.UP*0.14))
			tube_transforms.append(Transform3D(Basis.IDENTITY,anchor+Vector3.UP*0.28))
		var kind := "start" if i == 0 else ("finish" if i == gates.size()-1 else "checkpoint")
		symbols.append(RallyGateSymbols.create(root,kind,pose.origin+Vector3.UP*4.4))
	_build_blowers(blower_transforms)
	tube_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	tube_multimesh.use_colors = true
	tube_multimesh.mesh = _tube_mesh(material)
	tube_multimesh.instance_count = tube_transforms.size()
	for i: int in range(tube_transforms.size()): tube_multimesh.set_instance_transform(i,tube_transforms[i])
	var tubes := MultiMeshInstance3D.new()
	tubes.name = "InflatableTubes"
	tubes.multimesh = tube_multimesh
	tubes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tubes)
	update(0)


func update(next_gate: int) -> void:
	if next_gate==last_gate: return
	last_gate = next_gate
	for i: int in range(materials.size()):
		var color := Color("eab45c") if i==next_gate else (Color("42695a") if i<next_gate else Color("547e85"))
		for side: int in range(2):
			tube_multimesh.set_instance_color(i*2+side,color)
		symbols[i].visible = i == next_gate
		symbols[i].modulate = Color("ffe2a3")


func _tube_mesh(material: Material) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: int in range(12):
		for slice: int in range(10):
			for corner: Vector2i in [Vector2i(slice,band),Vector2i(slice+1,band),Vector2i(slice,band+1),Vector2i(slice+1,band),Vector2i(slice+1,band+1),Vector2i(slice,band+1)]:
				var angle := corner.x*TAU/10.0
				var height := corner.y*4.5/12.0
				tool.set_uv(Vector2(corner.x/10.0,corner.y/12.0))
				tool.add_vertex(Vector3(cos(angle)*0.24,height,sin(angle)*0.24))
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0,material)
	return mesh


func _build_blowers(transforms: Array[Transform3D]) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.65,0.28,0.65)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263a32")
	material.roughness = 0.95
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i: int in range(transforms.size()): multimesh.set_instance_transform(i,transforms[i])
	var blowers := MultiMeshInstance3D.new()
	blowers.name = "CheckpointBlowers"
	blowers.multimesh = multimesh
	blowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(blowers)

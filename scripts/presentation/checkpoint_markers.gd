class_name RallyCheckpointMarkers
extends RefCounted

var materials: Array[ShaderMaterial] = []
var labels: Array[Label3D] = []
var root := Node3D.new()
var last_gate: int = -1


func build(parent: Node3D,route: RallyStageRoute,gates: PackedFloat64Array) -> void:
	root.name = "InflatableCheckpoints"
	parent.add_child(root)
	for i: int in range(gates.size()):
		var pose := route.pose_at(gates[i],0)
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/checkpoint_air.gdshader")
		material.set_shader_parameter("phase",float(i)*0.83)
		materials.append(material)
		for side: float in [-1,1]:
			var anchor := pose.origin+pose.basis.x*side*(route.width_at(gates[i])*0.5+0.85)-Vector3.UP*0.15
			GrayboxGeometry.box(root,"Blower",Vector3(0.65,0.28,0.65),anchor+Vector3.UP*0.14,Color("263a32"))
			var tube := MeshInstance3D.new()
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for band: int in range(12):
				for slice: int in range(10):
					for corner: Vector2i in [Vector2i(slice,band),Vector2i(slice+1,band),Vector2i(slice,band+1),Vector2i(slice+1,band),Vector2i(slice+1,band+1),Vector2i(slice,band+1)]:
						var a := corner.x*TAU/10.0
						var h := corner.y*4.5/12.0
						tool.set_uv(Vector2(corner.x/10.0,corner.y/12.0))
						tool.add_vertex(Vector3(cos(a)*0.24,h,sin(a)*0.24))
			tool.generate_normals()
			tube.mesh = tool.commit()
			tube.material_override = material
			tube.position = anchor+Vector3.UP*0.28
			tube.extra_cull_margin = 0.6
			tube.visibility_range_end = 420
			root.add_child(tube)
		var label := Label3D.new()
		label.text = "CP %02d"%(i+1)
		label.position = pose.origin+Vector3.UP*5.0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.pixel_size = 0.013
		label.visibility_range_end = 320
		root.add_child(label)
		labels.append(label)


func update(next_gate: int) -> void:
	if next_gate==last_gate: return
	last_gate = next_gate
	for i: int in range(materials.size()):
		var color := Color("eab45c") if i==next_gate else (Color("42695a") if i<next_gate else Color("547e85"))
		materials[i].set_shader_parameter("tint",color)
		labels[i].text = ("NEXT  " if i==next_gate else "")+"CP %02d"%(i+1)
		labels[i].modulate = Color("ffe2a3") if i==next_gate else Color("aec5b9")

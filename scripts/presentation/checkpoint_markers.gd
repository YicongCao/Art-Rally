class_name RallyCheckpointMarkers
extends RefCounted

const PALETTE := {"desert": Color("5dffd5"), "autumn": Color("61e8ff"), "coast": Color("d69aff"), "highland": Color("ffc46b")}
const COLUMN_HEIGHT := 5.2
const SHOULDER_OFFSET := .85
var materials: Array[ShaderMaterial] = []
var symbols: Array[Sprite3D] = []
var root := Node3D.new()
var last_gate: int = -1
var column_multimesh := MultiMesh.new()
var base_multimesh := MultiMesh.new()
var column_gate_indices := PackedInt32Array()
var beam_material: ShaderMaterial
var light_time: float = 0.0
var gate_centers := PackedVector3Array()
var ground_lights: Array[OmniLight3D] = []
var light_gate: int = -1
var column_poses: Array[Transform3D] = []
var instance_states: Array[Color] = []
var light_color := Color("61e8ff")


func build(parent: Node3D,route: RallyStageRoute,gates: PackedFloat64Array) -> void:
	root.name = "LightCheckpoints"
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(root)
	light_color = PALETTE.get(route.definition.environment_id,PALETTE.autumn)
	beam_material = ShaderMaterial.new()
	beam_material.shader = preload("res://assets/shaders/checkpoint_light.gdshader")
	beam_material.set_shader_parameter("light_color",light_color)
	var base_material := ShaderMaterial.new()
	base_material.shader = preload("res://assets/shaders/checkpoint_projector.gdshader")
	base_material.set_shader_parameter("light_color",light_color)
	var wordmark := RallyFinishArch.logo_texture(root)
	for i: int in range(gates.size()):
		var pose := route.pose_at(gates[i],0)
		materials.append(beam_material)
		gate_centers.append(pose.origin)
		column_gate_indices.append(column_poses.size() if i>0 and i<gates.size()-1 else -1)
		if i>0 and i<gates.size()-1:
			for side: float in [-1,1]:
				var lateral := side*(route.width_at(gates[i])*.5+SHOULDER_OFFSET)
				var anchor := pose.origin+pose.basis.x*lateral
				anchor.y=pose.origin.y-SHOULDER_OFFSET*.18+route.road_relief(gates[i],lateral)
				# Keep light columns vertical even on graded roads.
				column_poses.append(Transform3D(Basis.IDENTITY,anchor))
		else:
			RallyFinishArch.build(root,route,gates[i],wordmark,"StartArch" if i==0 else "FinishArch")
		var kind := "start" if i==0 else ("finish" if i==gates.size()-1 else "checkpoint")
		symbols.append(RallyGateSymbols.create(root,kind,pose.origin+Vector3.UP*4.4))
	_build_batch(column_multimesh,_beam_mesh(),"LightColumns")
	_build_batch(base_multimesh,_base_mesh(base_material),"ProjectorBases")
	for side: int in range(2):
		var lamp := OmniLight3D.new()
		lamp.name="GroundLight%d"%side
		lamp.light_color=light_color
		lamp.omni_range=3.8
		lamp.omni_attenuation=1.6
		lamp.shadow_enabled=false
		lamp.visible=false
		root.add_child(lamp)
		ground_lights.append(lamp)
	update(0)


func _build_batch(batch: MultiMesh,mesh: ArrayMesh,node_name: String) -> void:
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.use_custom_data=true
	batch.mesh=mesh
	batch.instance_count=column_poses.size()
	for i: int in range(column_poses.size()):
		batch.set_instance_transform(i,column_poses[i])
		if batch==column_multimesh: instance_states.append(Color.WHITE)
	var node := MultiMeshInstance3D.new()
	node.name=node_name
	node.multimesh=batch
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)


func update(next_gate: int) -> void:
	if next_gate==last_gate: return
	if last_gate>0 and next_gate>last_gate:
		beam_material.set_shader_parameter("passed_gate",last_gate)
		beam_material.set_shader_parameter("passed_time",light_time)
	last_gate=next_gate
	for i: int in range(gate_centers.size()):
		var state := 1.0 if i==next_gate else (.13 if i<next_gate else .48)
		if column_gate_indices[i]>=0:
			for side: int in range(2):
				var index := column_gate_indices[i]+side
				instance_states[index]=Color(state,float(i),fmod(i*.137+side*.31,1.0),1)
				column_multimesh.set_instance_custom_data(index,instance_states[index])
				base_multimesh.set_instance_custom_data(index,instance_states[index])
		symbols[i].visible=i==next_gate
		symbols[i].modulate=light_color if i>0 and i<gate_centers.size()-1 else Color("ffe2a3")


func _beam_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A camera-facing veil gives the beam a soft luminous edge without a solid tube.
	for uv: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
		tool.set_uv(uv)
		tool.set_uv2(Vector2.ZERO)
		tool.add_vertex(Vector3((uv.x-.5)*1.7,.24+uv.y*(COLUMN_HEIGHT-.24),0))
	# A restrained soft footprint supplements the two nearby ground lights.
	for uv: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
		tool.set_uv(uv)
		tool.set_uv2(Vector2(1,0))
		tool.add_vertex(Vector3((uv.x-.5)*2.5,.035,(uv.y-.5)*2.5))
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0,beam_material)
	return mesh


func _base_mesh(material: Material) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Three stepped hexagonal sections: graphite foot, luminous lens ring, dark rim.
	for tier: int in range(3):
		var cylinder := CylinderMesh.new()
		cylinder.radial_segments=6
		cylinder.rings=1
		cylinder.bottom_radius=[.40,.31,.29][tier]
		cylinder.top_radius=[.34,.31,.27][tier]
		cylinder.height=[.17,.035,.045][tier]
		var arrays := cylinder.get_mesh_arrays()
		var masks := PackedVector2Array()
		masks.resize(arrays[Mesh.ARRAY_VERTEX].size())
		masks.fill(Vector2(1 if tier==1 else 0,0))
		arrays[Mesh.ARRAY_TEX_UV2]=masks
		var piece := ArrayMesh.new()
		piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		tool.append_from(piece,0,Transform3D(Basis.IDENTITY,Vector3(0,[.085,.1875,.2275][tier],0)))
	var mesh := tool.commit()
	mesh.surface_set_material(0,material)
	return mesh


func advance(dt: float,listener: Vector3) -> void:
	if root.get_tree().paused: return
	light_time+=dt
	beam_material.set_shader_parameter("light_time",light_time)
	light_gate=-1
	var closest := 42.0
	for i: int in range(1,gate_centers.size()-1):
		var distance := listener.distance_to(gate_centers[i])
		if distance<closest:
			closest=distance
			light_gate=i
	for side: int in range(2):
		var lamp := ground_lights[side]
		lamp.visible=light_gate>=0
		if light_gate<0: continue
		var index := column_gate_indices[light_gate]+side
		lamp.position=column_poses[index].origin+Vector3.UP*.65
		lamp.light_energy=2.1*instance_states[index].r*(1-smoothstep(25,42,closest))

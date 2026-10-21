class_name RallyCheckpointMarkers
extends RefCounted

var materials: Array[ShaderMaterial] = []
var symbols: Array[Sprite3D] = []
var root := Node3D.new()
var last_gate: int = -1
var tube_multimesh := MultiMesh.new()
var tube_gate_indices := PackedInt32Array()
var air_material: ShaderMaterial
var air_time: float = 0.0
var gate_centers := PackedVector3Array()
var fan_players: Array[AudioStreamPlayer3D] = []
var fan_gate: int = -1
var tube_poses: Array[Transform3D] = []
var instance_states: Array[Color] = []


func build(parent: Node3D,route: RallyStageRoute,gates: PackedFloat64Array) -> void:
	root.name = "InflatableCheckpoints"
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(root)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/checkpoint_air.gdshader")
	air_material=material
	var wordmark := RallyFinishArch.logo_texture(root)
	var blower_transforms: Array[Transform3D] = []
	for i: int in range(gates.size()):
		var pose := route.pose_at(gates[i],0)
		materials.append(material)
		gate_centers.append(pose.origin)
		tube_gate_indices.append(tube_poses.size() if i>0 and i<gates.size()-1 else -1)
		for side: float in [-1,1]:
			var anchor := pose.origin+pose.basis.x*side*(route.width_at(gates[i])*0.5+0.85)-Vector3.UP*0.15
			if i>0 and i<gates.size()-1:
				# +X is always OUTWARD. Rotate, never negatively scale a one-sided mesh.
				var basis := pose.basis*Basis(Vector3.UP,PI if side<0 else 0.0)
				anchor.y=pose.origin.y-.85*.18+route.road_relief(gates[i],side*(route.width_at(gates[i])*.5+.85))
				tube_poses.append(Transform3D(basis,anchor))
			else: blower_transforms.append(Transform3D(Basis.IDENTITY,anchor+Vector3.UP*0.14))
		if i==0 or i==gates.size()-1:
			RallyFinishArch.build(root,route,gates[i],wordmark,"StartArch" if i==0 else "FinishArch")
		var kind := "start" if i == 0 else ("finish" if i == gates.size()-1 else "checkpoint")
		symbols.append(RallyGateSymbols.create(root,kind,pose.origin+Vector3.UP*4.4))
	_build_blowers(blower_transforms)
	tube_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	tube_multimesh.use_colors = true
	tube_multimesh.use_custom_data = true
	tube_multimesh.mesh = _tube_mesh(material)
	tube_multimesh.instance_count = tube_poses.size()
	for i: int in range(tube_poses.size()):
		tube_multimesh.set_instance_transform(i,tube_poses[i])
		tube_multimesh.set_instance_color(i,Color.WHITE)
		instance_states.append(Color.WHITE)
	var tubes := MultiMeshInstance3D.new()
	tubes.name = "InflatableTubes"
	tubes.multimesh = tube_multimesh
	tubes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tubes)
	# Two reusable spatial players, not one audio source for every distant gate.
	for side: int in range(2):
		var player := AudioStreamPlayer3D.new()
		player.name="PressureFan%d"%side
		player.stream=RallyAudioDirector.asset("checkpoint_blower",true)
		player.bus="Environment" if AudioServer.get_bus_index("Environment")>=0 else "Master"
		player.unit_size=5
		player.max_distance=36
		player.volume_db=-18
		root.add_child(player)
		fan_players.append(player)
	update(0)


func update(next_gate: int) -> void:
	if next_gate==last_gate: return
	if last_gate>0 and next_gate>last_gate:
		air_material.set_shader_parameter("flutter_gate",last_gate)
		air_material.set_shader_parameter("flutter_time",air_time)
	last_gate = next_gate
	for i: int in range(materials.size()):
		var state := 1.0 if i==next_gate else (0.0 if i<next_gate else .65)
		if tube_gate_indices[i]>=0:
			for side: int in range(2):
				var index := tube_gate_indices[i]+side
				instance_states[index]=Color(state,float(i),fmod(i*.137+side*.31,1.0),1)
				tube_multimesh.set_instance_custom_data(index,instance_states[index])
		symbols[i].visible = i == next_gate
		symbols[i].modulate = Color("ffe2a3")


func _tube_mesh(material: Material) -> ArrayMesh:
	var path := "res://assets/screenprint/props/checkpoint.glb"
	if ResourceLoader.exists(path):
		var source: Node3D=load(path).instantiate()
		var merged := SurfaceTool.new()
		merged.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Node in source.find_children("*","MeshInstance3D",true,false):
			var pose: Transform3D=part.transform
			var ancestor := part.get_parent()
			while ancestor!=source and ancestor is Node3D:
				pose=ancestor.transform*pose
				ancestor=ancestor.get_parent()
			for surface: int in range(part.mesh.get_surface_count()):
				var arrays: Array=part.mesh.surface_get_arrays(surface)
				var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
				var color := original.albedo_color.srgb_to_linear() if original!=null else Color.WHITE
				var tag := original.resource_name if original!=null else ""
				var mask := 4.0 if tag.begins_with("Vortex") else (3.0 if tag.begins_with("FanRotor") else (2.0 if tag.begins_with("Ribbon") else (1.0 if tag.begins_with("Air") else 0.0)))
				var count: int=arrays[Mesh.ARRAY_VERTEX].size()
				var colors := PackedColorArray()
				colors.resize(count); colors.fill(color)
				var masks := PackedVector2Array()
				masks.resize(count); masks.fill(Vector2(mask,0))
				arrays[Mesh.ARRAY_COLOR]=colors
				arrays[Mesh.ARRAY_TEX_UV2]=masks
				var piece := ArrayMesh.new()
				piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				merged.append_from(piece,0,pose)
		var result := merged.commit()
		result.surface_set_material(0,material)
		source.free()
		return result
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: int in range(12):
		for slice: int in range(10):
			for corner: Vector2i in [Vector2i(slice,band),Vector2i(slice+1,band),Vector2i(slice,band+1),Vector2i(slice+1,band),Vector2i(slice+1,band+1),Vector2i(slice,band+1)]:
				var angle := corner.x*TAU/10.0
				var height := corner.y*4.5/12.0
				tool.set_uv(Vector2(corner.x/10.0,corner.y/12.0))
				tool.set_uv2(Vector2(1,0))
				tool.set_color(Color("df5428").srgb_to_linear())
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


func advance(dt: float,listener: Vector3) -> void:
	if root.get_tree().paused: return
	air_time+=dt
	air_material.set_shader_parameter("air_time",air_time)
	var closest := -1
	var distance := 36.0
	for i: int in range(1,gate_centers.size()-1):
		var d := listener.distance_to(gate_centers[i])
		if d<distance:
			distance=d
			closest=i
	if closest<0:
		for player: AudioStreamPlayer3D in fan_players: player.stop()
		fan_gate=-1
		return
	if closest!=fan_gate:
		fan_gate=closest
		for side: int in range(2):
			var pose := tube_poses[tube_gate_indices[closest]+side]
			fan_players[side].position=pose*Vector3(0,.35,-1.06)
	for player: AudioStreamPlayer3D in fan_players:
		if not player.playing and DisplayServer.get_name()!="headless": player.play()

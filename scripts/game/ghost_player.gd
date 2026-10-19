class_name RallyGhostPlayer
extends Node3D

var recording: Dictionary = {}
var wheels: Array[Node3D] = []
var material := StandardMaterial3D.new()
var definition: RallyVehicleDefinition
var solid: bool = false
var outline_materials: Array[ShaderMaterial] = []


func build(vehicle: RallyVehicleDefinition, data: Dictionary,translucent: bool = true) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	solid = not translucent
	definition = vehicle
	recording = data
	material.albedo_color = Color(0.48,0.92,0.96,0.27)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	var body: Node3D
	if ResourceLoader.exists(vehicle.model_path): body = RallyVehicleAppearance.build(vehicle)
	else:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = vehicle.body_size
		box.mesh = mesh
		body = box
	add_child(body)
	if not solid: _tint(body)
	for i: int in range(4):
		var pivot := Node3D.new()
		add_child(pivot)
		wheels.append(pivot)
		var tire := MeshInstance3D.new()
		tire.mesh = RallyWheelMeshes.tire(.34)
		tire.rotation.z = PI/2
		pivot.add_child(tire)
		for side: float in [-1,1]:
			var hub := MeshInstance3D.new()
			hub.mesh=RallyWheelMeshes.five_spoke()
			hub.position.y=side*.125
			tire.add_child(hub)
		if not solid: _tint(tire)
	visible = false


func _tint(node: Node) -> void:
	if node is MeshInstance3D:
		if str(node.name).begins_with("Outline_"):
			var line := ShaderMaterial.new()
			line.shader=preload("res://assets/shaders/screenprint_ghost_outline.gdshader")
			line.set_shader_parameter("ink",material.albedo_color)
			line.set_shader_parameter("opacity",material.albedo_color.a)
			node.material_override=line
			outline_materials.append(line)
		else: node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children(): _tint(child)


func update(time: float, player_position: Vector3, enabled: bool) -> void:
	var sample := RallyGhostRecording.sample(recording,time) if enabled and not recording.is_empty() else {}
	visible = not sample.is_empty()
	if not visible: return
	transform = sample.pose
	var distance := position.distance_to(player_position)
	if not solid:
		material.albedo_color.a = 0.27*smoothstep(2,7,distance)
		for line: ShaderMaterial in outline_materials: line.set_shader_parameter("opacity",material.albedo_color.a)
		visible = distance>2
	for i: int in range(4):
		wheels[i].position = Vector3((-0.5 if i%2==0 else 0.5)*definition.track_width,-sample.lengths[i],(-0.5 if i<2 else 0.5)*definition.wheelbase)
		wheels[i].rotation.y = sample.steer if i<2 else 0
		wheels[i].get_child(0).rotation.x = -fmod(sample.spins[i],TAU)

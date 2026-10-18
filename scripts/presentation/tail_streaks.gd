class_name RallyTailStreaks
extends RefCounted

var visual := MeshInstance3D.new()
var mesh := ImmediateMesh.new()
var history: Array[Dictionary] = []
var clock: float = 0
var width: float = 1.6
var length: float = 3.8
var lamp_edge: float = .71

func build(parent: Node3D,body: Vector3,vehicle_id: String = "A240") -> void:
	width = body.x
	length = body.z
	lamp_edge = width*.5-.17+({"F160":.11,"R200":.53,"A240":.48}.get(vehicle_id,.48))*.5
	visual.name = "TailLightSlipstreams"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	visual.material_override = material
	parent.add_child(visual)

func clear() -> void:
	history.clear()
	mesh.clear_surfaces()

func update(pose: Transform3D,speed: float,dt: float,camera: Camera3D) -> void:
	clock += dt
	var intensity := smoothstep(8,28,speed)
	if intensity<=.001:
		clear()
		return
	var left := pose*Vector3(-lamp_edge,.20,length*.5+.009)
	var right := pose*Vector3(lamp_edge,.20,length*.5+.009)
	if not history.is_empty() and (left.distance_to(history[-1].left)>12 or dt>.25): clear()
	history.append({"left":left,"right":right,"time":clock,"intensity":intensity})
	while not history.is_empty() and (clock-float(history[0].time)>.5 or history.size()>48): history.pop_front()
	mesh.clear_surfaces()
	if history.size()<2: return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: String in ["left","right"]:
		for i: int in range(1,history.size()):
			var a: Vector3 = history[i-1][side]
			var b: Vector3 = history[i][side]
			var tangent := b-a
			if tangent.length_squared()<.00001: tangent = Vector3.FORWARD
			var across := tangent.normalized().cross((camera.global_position-b).normalized()).normalized()
			var old_age := clampf((clock-float(history[i-1].time))/.5,0,1)
			var age := clampf((clock-float(history[i].time))/.5,0,1)
			var wa := .07*(1-old_age)*(.3+.7*intensity)
			var wb := .07*(1-age)*(.3+.7*intensity)
			var ca := Color(1.0,.018,.008,(1-old_age)*(1-old_age)*.42*intensity)
			var cb := Color(1.0,.025,.012,(1-age)*(1-age)*.48*intensity) if age<.12 else Color(1.0,.018,.008,(1-age)*(1-age)*.42*intensity)
			for corner: int in [0,1,2,2,1,3]:
				mesh.surface_set_color(ca if corner<2 else cb)
				mesh.surface_add_vertex([a-across*wa,a+across*wa,b-across*wb,b+across*wb][corner])
	mesh.surface_end()

class_name RallySampleCar
extends RefCounted

var body := Node3D.new()
var brake_material := StandardMaterial3D.new()
var original_visuals: Array[Node3D] = []
var original_hubs: Array[Node3D] = []
var styled_hubs: Array[Node3D] = []


func build(car: RallyVehicle, definition: RallyVehicleDefinition = null) -> void:
	if definition!=null and ResourceLoader.exists(definition.model_path):
		_build_model(car,definition)
		return
	body.name = "PreviewBodywork"
	car.add_child(body)
	for node_name: String in ["Body","Cabin","HoodStripe"]:
		var node: Node3D = car.get_node(node_name)
		original_visuals.append(node)
		node.visible = false
	var builder := RallySampleMeshes.new()
	var orange := Color("c96332")
	var cream := Color("e7e0c9")
	var dark := Color("242f31")
	var glass := Color("314854")
	var sections: Array[Vector4] = [Vector4(-2.02,0.70,-0.17,0.13),Vector4(-1.65,0.84,-0.22,0.24),Vector4(-0.67,0.87,-0.22,0.29),Vector4(0.8,0.87,-0.22,0.31),Vector4(1.8,0.83,-0.18,0.26),Vector4(2.01,0.73,-0.15,0.16)]
	for i: int in range(sections.size()-1):
		var a := sections[i]
		var b := sections[i+1]
		var va: Array[Vector3] = [Vector3(-a.y,a.z,a.x),Vector3(a.y,a.z,a.x),Vector3(a.y,a.w,a.x),Vector3(-a.y,a.w,a.x)]
		var vb: Array[Vector3] = [Vector3(-b.y,b.z,b.x),Vector3(b.y,b.z,b.x),Vector3(b.y,b.w,b.x),Vector3(-b.y,b.w,b.x)]
		for edge: int in range(4):
			quad(builder,va[edge],vb[edge],vb[(edge+1)%4],va[(edge+1)%4],orange if edge != 2 else cream)
	quad(builder,Vector3(-0.70,-0.17,-2.02),Vector3(0.70,-0.17,-2.02),Vector3(0.70,0.13,-2.02),Vector3(-0.70,0.13,-2.02),orange)
	quad(builder,Vector3(-0.73,-0.15,2.01),Vector3(-0.73,0.16,2.01),Vector3(0.73,0.16,2.01),Vector3(0.73,-0.15,2.01),orange)
	# Original hatchback proportions; glass is split by geometry pillars, not image decals.
	quad(builder,Vector3(-0.77,0.29,-0.72),Vector3(-0.61,0.88,-0.27),Vector3(0.61,0.88,-0.27),Vector3(0.77,0.29,-0.72),glass)
	quad(builder,Vector3(-0.61,0.88,-0.27),Vector3(-0.60,0.87,0.68),Vector3(0.60,0.87,0.68),Vector3(0.61,0.88,-0.27),orange)
	quad(builder,Vector3(-0.60,0.87,0.68),Vector3(-0.75,0.30,1.32),Vector3(0.75,0.30,1.32),Vector3(0.60,0.87,0.68),glass)
	for side: float in [-1,1]:
		quad(builder,Vector3(side*0.78,0.30,-0.63),Vector3(side*0.61,0.84,-0.23),Vector3(side*0.605,0.84,0.17),Vector3(side*0.78,0.30,0.17),glass)
		quad(builder,Vector3(side*0.78,0.30,0.23),Vector3(side*0.605,0.84,0.23),Vector3(side*0.59,0.83,0.66),Vector3(side*0.75,0.30,1.24),glass)
		builder.beam(Vector3(side*0.77,0.29,-0.73),Vector3(side*0.61,0.88,-0.27),0.035,cream)
		builder.beam(Vector3(side*0.60,0.87,0.68),Vector3(side*0.75,0.30,1.32),0.045,orange)
		builder.beam(Vector3(side*0.61,0.86,0.2),Vector3(side*0.78,0.3,0.2),0.035,cream)
		builder.box(Vector3(0.045,0.20,1.65),Vector3(side*0.875,0.08,0.05),cream)
		builder.box(Vector3(0.2,0.10,0.25),Vector3(side*0.96,0.37,-0.52),orange)
		builder.box(Vector3(0.10,0.38,0.045),Vector3(side*0.83,-0.30,1.72),dark)
		builder.box(Vector3(0.07,0.31,0.10),Vector3(side*0.65,0.53,1.65),dark)
		for axle: float in [-1.3,1.3]:
			for segment: int in range(12):
				var a := segment*PI/12
				var b := (segment+1)*PI/12
				var center := Vector3(side*0.91,-0.34,axle)
				quad(builder,center+Vector3(0,sin(a)*0.43,cos(a)*0.43),center+Vector3(0,sin(b)*0.43,cos(b)*0.43),center+Vector3(0,sin(b)*0.52,cos(b)*0.52),center+Vector3(0,sin(a)*0.52,cos(a)*0.52),orange)
	builder.box(Vector3(1.98,0.08,0.30),Vector3(0,0.72,1.67),dark,Vector3(-0.08,0,0))
	builder.box(Vector3(1.60,0.15,0.15),Vector3(0,-0.10,1.99),dark)
	builder.box(Vector3(1.52,0.14,0.12),Vector3(0,-0.10,-2.01),dark)
	builder.box(Vector3(0.62,0.12,0.05),Vector3(0,0.09,2.045),cream)
	builder.box(Vector3(0.43,0.08,0.7),Vector3(0,0.27,-1.2),orange)
	builder.box(Vector3(0.40,0.08,0.25),Vector3(0,0.92,0),cream)
	builder.beam(Vector3(-0.48,0.81,0.76),Vector3(0.66,0.32,1.29),0.018,Color("a5b0aa"))
	builder.beam(Vector3(0.48,0.81,0.76),Vector3(-0.66,0.32,1.29),0.018,Color("a5b0aa"))
	builder.beam(Vector3(0,0.9,0.55),Vector3(0,1.34,0.75),0.008,dark)
	var mesh := MeshInstance3D.new()
	mesh.mesh = builder.finish()
	body.add_child(mesh)
	brake_material.albedo_color = Color("8f2720")
	brake_material.emission_enabled = true
	brake_material.emission = Color("e5462d")
	brake_material.emission_energy_multiplier = 0.15
	for side: float in [-1,1]:
		var light := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.29,0.14,0.055)
		light.mesh = box
		light.position = Vector3(side*0.57,0.14,1.985)
		light.material_override = brake_material
		body.add_child(light)


static func quad(builder: RallySampleMeshes, a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	for v: Vector3 in [a,b,c,a,c,d]:
		builder.tool.set_color(color.srgb_to_linear())
		builder.tool.add_vertex(v)


func set_style(enabled: bool) -> void:
	body.visible = enabled
	for node: Node3D in original_visuals: node.visible = not enabled
	for node: Node3D in original_hubs: node.visible = not enabled
	for node: Node3D in styled_hubs: node.visible = enabled


func _build_model(car: RallyVehicle, definition: RallyVehicleDefinition) -> void:
	body.free()
	body = RallyVehicleAppearance.build(definition)
	body.name = definition.vehicle_id+"Bodywork"
	car.add_child(body)
	for node_name: String in ["Body","Cabin","HoodStripe"]:
		var original: Node3D = car.get_node(node_name)
		original_visuals.append(original)
		original.visible = false
	brake_material.albedo_color = Color("95261e")
	brake_material.emission_enabled = true
	brake_material.emission = Color("f45a36")
	_bind_lamps(body)
	if definition.vehicle_id=="WRX":
		var gold:=StandardMaterial3D.new()
		gold.albedo_color=Color("d6b046")
		for wheel: Node3D in car.wheel_visuals:
			for node: Node in wheel.find_children("WhiteFiveSpoke","MeshInstance3D",true,false): node.material_override=gold



func _bind_lamps(node: Node) -> void:
	if node is MeshInstance3D and str(node.name).begins_with("BrakeLamp"): node.material_override = brake_material
	for child: Node in node.get_children(): _bind_lamps(child)

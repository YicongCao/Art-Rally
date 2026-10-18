class_name RallyVehiclePlate
extends Node3D

var labels: Array[Label3D] = []
var plate_text: String = ""


static func attach(body: Node3D, definition: RallyVehicleDefinition, text: String) -> RallyVehiclePlate:
	var plates := RallyVehiclePlate.new()
	plates.name = "PlayerLicensePlates"
	body.add_child(plates)
	for side: float in [1,-1]:
		var mount := Node3D.new()
		mount.name = "Rear" if side>0 else "Front"
		mount.position = Vector3(0,.02,side*(definition.body_size.z/2+.052))
		mount.rotation.y = 0 if side>0 else PI
		plates.add_child(mount)
		var frame := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(.70,.17,.025)
		frame.mesh = box
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color("192d2b")
		dark.roughness = .8
		frame.material_override = dark
		mount.add_child(frame)
		var paper := MeshInstance3D.new()
		var face := QuadMesh.new()
		face.size = Vector2(.675,.145)
		paper.mesh = face
		paper.position.z = .013
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("f1e9d6")
		material.roughness = .8
		paper.material_override = material
		mount.add_child(paper)
		var label := Label3D.new()
		label.position.z = .015
		label.font = RallyPlateText.font()
		label.font_size = 64
		label.outline_size = 0
		label.modulate = Color("192d2b")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.no_depth_test = false
		mount.add_child(label)
		plates.labels.append(label)
	plates.set_text(text)
	return plates


func set_text(value: String) -> void:
	plate_text = RallyPlateText.display(value)
	var font := RallyPlateText.font()
	var width := font.get_string_size(plate_text,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x
	for label: Label3D in labels:
		label.text = plate_text
		# Enlarge the old type by 20%, capped at 10% inset on each edge of the frame.
		var old_size := minf(.105/font.get_height(64),.60/maxf(1,width))
		label.pixel_size = minf(old_size*1.2,minf(.17*.8/font.get_height(64),.70*.8/maxf(1,width)))

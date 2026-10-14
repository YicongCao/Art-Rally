class_name GrayboxGeometry
extends RefCounted


static func box(parent: Node3D, label: String, size: Vector3, at: Vector3, color: Color, solid: bool = false, rotation: Vector3 = Vector3.ZERO) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	node.position = at
	node.rotation_degrees = rotation
	if solid:
		node.collision_layer = 1
		node.collision_mask = 2
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		node.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	mesh.material = material
	visual.mesh = mesh
	node.add_child(visual)
	parent.add_child(node)
	return node


static func label(parent: Node3D, text: String, at: Vector3) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.position = at
	sign.font_size = 64
	sign.pixel_size = 0.015
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("e8d9b7")
	parent.add_child(sign)

class_name RallyWheelMeshes
extends RefCounted

static var tires: Dictionary = {}
static var rim: ArrayMesh

# Local Y is the axle, matching the existing tire deformation/spin transform.
static func tire(radius: float) -> ArrayMesh:
	if tires.has(radius): return tires[radius]
	var authored := authored_mesh("wheel_tire")
	if authored!=null and is_equal_approx(radius,.34):
		tires[radius]=authored
		return authored
	var b := RallySampleMeshes.new()
	var rubber := Color("29302e")
	var casing := TorusMesh.new()
	casing.inner_radius=radius*.58
	casing.outer_radius=radius-.010
	casing.rings=48
	casing.ring_segments=12
	b.append(casing,Transform3D(Basis.IDENTITY.scaled(Vector3(1,1.7,1)),Vector3.ZERO),rubber)
	# Four staggered rows of actual tread blocks with open drainage channels.
	for row: int in range(44):
		for lane: int in range(4):
			var angle: float = (row+(.44 if lane%2 else 0))*TAU/44
			var at := Vector3(cos(angle)*(radius-.007),(lane-1.5)*.049,sin(angle)*(radius-.007))
			var radial := Vector3(cos(angle),0,sin(angle))
			var tangent := Vector3(-sin(angle),0,cos(angle))
			var basis := Basis(tangent,Vector3.UP,-radial)*Basis(Vector3.FORWARD,.22 if lane<2 else -.22)
			var block := BoxMesh.new()
			block.size=Vector3(.033,.036,.014)
			b.append(block,Transform3D(basis,at),Color("38403a").darkened(.035*(row%3)))
	# Sidewall shoulder lugs continue the AT pattern down both sides.
	for side: float in [-1,1]:
		for i: int in range(22):
			var angle := i*TAU/22
			b.box(Vector3(.043,.012,.021),Vector3(cos(angle)*radius*.84,side*.105,sin(angle)*radius*.84),Color("353c37"),Vector3(0,-angle,0))
	var mesh := b.finish()
	tires[radius]=mesh
	return mesh

static func five_spoke() -> ArrayMesh:
	if rim!=null: return rim
	rim=authored_mesh("wheel_rim")
	if rim!=null: return rim
	var b := RallySampleMeshes.new()
	var white := Color("ebe8dc")
	var ring := TorusMesh.new()
	ring.inner_radius=.172
	ring.outer_radius=.205
	ring.rings=36
	ring.ring_segments=8
	b.append(ring,Transform3D(Basis.IDENTITY.scaled(Vector3(1,.7,1)),Vector3.ZERO),white)
	b.cone(.051,.048,.043,Vector3.ZERO,white,12)
	for i: int in range(5):
		var angle := i*TAU/5
		b.box(Vector3(.051,.032,.153),Vector3(sin(angle)*.113,0,cos(angle)*.113),white,Vector3(0,angle,0))
		for side: float in [-1,1]:
			b.cone(.007,.007,.004,Vector3(sin(angle)*.031,side*.024,cos(angle)*.031),Color("616c66"),6)
	# Recessed dark brake disc: the five open spaces remain legible from the side.
	b.cone(.163,.163,.008,Vector3(0,-.022,0),Color("59615c"),32)
	rim=b.finish()
	return rim

static func install_hubs(pivot: Node3D) -> void:
	for index: int in [1,2]:
		var hub: Node3D=pivot.get_child(index)
		for child: Node in hub.get_children(): child.visible=false
		var visual := MeshInstance3D.new()
		visual.name="WhiteFiveSpoke"
		visual.mesh=five_spoke()
		visual.rotation.z=-signf(hub.position.x)*PI*.5
		hub.add_child(visual)


static func authored_mesh(kind: String) -> ArrayMesh:
	var path := "res://assets/screenprint/props/"+kind+".glb"
	if not ResourceLoader.exists(path): return null
	var source: Node3D=load(path).instantiate()
	var builder := RallySampleMeshes.new()
	_append_authored(source,Transform3D.IDENTITY,builder)
	source.free()
	return builder.finish()

static func _append_authored(node: Node3D,parent_pose: Transform3D,builder: RallySampleMeshes) -> void:
	var pose := parent_pose*node.transform
	if node is MeshInstance3D:
		for surface: int in range(node.mesh.get_surface_count()):
			var data: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=data[Mesh.ARRAY_INDEX]
			var material := node.mesh.surface_get_material(surface) as StandardMaterial3D
			builder.tool.set_color((material.albedo_color if material!=null else Color.WHITE).srgb_to_linear())
			for index: int in indices: builder.tool.add_vertex(pose*vertices[index])
	for child: Node in node.get_children():
		if child is Node3D: _append_authored(child,pose,builder)

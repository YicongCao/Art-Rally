class_name RallyWheelMeshes
extends RefCounted

static var tires: Dictionary = {}
static var rim: ArrayMesh

# Local Y is the axle, matching the existing tire deformation/spin transform.
static func tire(radius: float,compound: String = "stock") -> ArrayMesh:
	var key := str(radius)+compound
	if tires.has(key): return tires[key]
	var authored := authored_mesh("wheel_tire")
	if authored!=null and is_equal_approx(radius,.34) and compound=="stock":
		tires[key]=authored
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
	for row: int in range(0 if compound=="road" else 44):
		for lane: int in range(4):
			var angle: float = (row+(.44 if lane%2 else 0))*TAU/44
			var at := Vector3(cos(angle)*(radius-.007),(lane-1.5)*.049,sin(angle)*(radius-.007))
			var radial := Vector3(cos(angle),0,sin(angle))
			var tangent := Vector3(-sin(angle),0,cos(angle))
			var basis := Basis(tangent,Vector3.UP,-radial)*Basis(Vector3.FORWARD,.22 if lane<2 else -.22)
			var block := BoxMesh.new()
			block.size=Vector3(.044 if compound=="sand" else .033,.036,.024 if compound=="sand" else .014)
			b.append(block,Transform3D(basis,at),Color("38403a").darkened(.035*(row%3)))
	# Sidewall shoulder lugs continue the AT pattern down both sides.
	for side: float in [-1,1]:
		for i: int in range(0 if compound=="road" else 22):
			var angle := i*TAU/22
			b.box(Vector3(.043,.012,.021),Vector3(cos(angle)*radius*.84,side*.105,sin(angle)*radius*.84),Color("353c37"),Vector3(0,-angle,0))
	var mesh := b.finish()
	tires[key]=mesh
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

# High-fidelity five-twin-spoke aero rim for the P7, smooth shaded; local Y is the axle.
static var hifi_rim: ArrayMesh
static func aero_rim() -> ArrayMesh:
	if hifi_rim!=null: return hifi_rim
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var silver := Color("c9cfd2").srgb_to_linear()
	var dark := Color("2c3134").srgb_to_linear()
	var caliper := Color("d0412f").srgb_to_linear()
	var segments := 96
	# Outer lip and barrel: a lathe profile (radius, axial offset).
	var lathe := [Vector2(.215,.010),Vector2(.222,.018),Vector2(.226,.030),Vector2(.222,.040),Vector2(.205,.044),Vector2(.200,-.06)]
	for i: int in range(segments):
		var a0 := TAU*i/segments
		var a1 := TAU*(i+1)/segments
		for k: int in range(lathe.size()-1):
			var p0: Vector2=lathe[k]
			var p1: Vector2=lathe[k+1]
			var color := silver if k<4 else dark
			var quad := [Vector3(cos(a0)*p0.x,p0.y,sin(a0)*p0.x),Vector3(cos(a1)*p0.x,p0.y,sin(a1)*p0.x),Vector3(cos(a1)*p1.x,p1.y,sin(a1)*p1.x),Vector3(cos(a0)*p1.x,p1.y,sin(a0)*p1.x)]
			for index: int in [0,2,1,0,3,2]:
				tool.set_color(color)
				tool.add_vertex(quad[index])
	# Ten twisted spokes in five pairs, each a tapered swept blade with a raised ridge.
	for spoke: int in range(10):
		var base := TAU*(spoke/2)/5
		var rows: Array=[]
		for r: int in range(9):
			var t := r/8.0
			var radius := lerpf(.055,.205,t)
			# Twin spokes stay a constant ~34 mm apart (not converging), with a gentle sweep.
			var offset := (.022 if spoke%2 else -.022)/radius
			var twist := base+offset+t*.18
			var half := lerpf(.012,.010,t)
			var ridge := lerpf(.040,.026,t)
			var row: Array=[]
			for c: int in range(5):
				var u := (c/4.0)*2-1
				var angle := twist+u*half/radius
				var height := ridge*(1-u*u*.65)+.004
				row.append(Vector3(cos(angle)*radius,height,sin(angle)*radius))
			rows.append(row)
		for r: int in range(8):
			for c: int in range(4):
				var q := [rows[r][c],rows[r][c+1],rows[r+1][c+1],rows[r+1][c]]
				for index: int in [0,2,1,0,3,2]:
					tool.set_color(silver)
					tool.add_vertex(q[index])
	# Centre cap, dark brake disc and red caliper behind the spokes.
	for i: int in range(segments):
		var a0 := TAU*i/segments
		var a1 := TAU*(i+1)/segments
		for ring: Array in [[0.0,.058,.046,.040,silver],[.06,.19,-.03,-.03,dark]]:
			var r0: float=ring[0]
			var r1: float=ring[1]
			var y0: float=ring[2]
			var y1: float=ring[3]
			var q := [Vector3(cos(a0)*r0,y0,sin(a0)*r0),Vector3(cos(a1)*r0,y0,sin(a1)*r0),Vector3(cos(a1)*r1,y1,sin(a1)*r1),Vector3(cos(a0)*r1,y1,sin(a0)*r1)]
			for index: int in [0,2,1,0,3,2]:
				tool.set_color(ring[4])
				tool.add_vertex(q[index])
	# Caliper block sits behind the spokes at the rear of the disc.
	var caliper_box := BoxMesh.new()
	caliper_box.size=Vector3(.09,.03,.13)
	var data := caliper_box.get_mesh_arrays()
	var vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=data[Mesh.ARRAY_INDEX]
	for index: int in indices:
		tool.set_color(caliper)
		tool.add_vertex(vertices[index]+Vector3(.15,-.02,0))
	tool.generate_normals()
	hifi_rim=tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.metallic=.75
	material.roughness=.3
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	hifi_rim.surface_set_material(0,material)
	return hifi_rim


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

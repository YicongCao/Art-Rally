class_name RallyStageLandmarks
extends RefCounted

# Original faceted scenery, measured in metres. All people sit behind barriers.
static func build(land: RallyStageScenery) -> void:
	_service(land,land.route.length*.51)
	_corner_markers(land)
	match land.generator.definition.environment_id:
		"autumn": _arch(land,land.route.length*.53)
		"coast": _coast(land)
		"highland": _summit(land)
		"desert": _mesa_overlook(land)


static func _root(land: RallyStageScenery,title: String,s: float,lateral: float) -> Node3D:
	var node := Node3D.new()
	node.name = title
	land.dressing.add_child(node)
	node.position = land.ground_at(s,lateral)
	# Vertical props remain upright even on a steep hill.
	node.rotation.y = land.route.pose_at(s).basis.get_euler().y
	return node


static func _mesh(parent: Node3D,builder: RallySampleMeshes,solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = builder.finish()
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 4
		body.collision_mask = 2
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(collision)
		parent.add_child(body)
	return mesh


static func _person(b: RallySampleMeshes,at: Vector3,shirt: Color,swim: bool = false) -> void:
	var skin := Color("c99270")
	b.ellipsoid(Vector3(.15,.19,.15),at+Vector3(0,1.63,0),skin)
	b.cone(.18,.23,.54,at+Vector3(0,1.12,0),skin if swim else shirt,6)
	if swim:
		# Adult beachgoers, simplified two-piece swimwear in the same low-poly style.
		b.cone(.21,.23,.14,at+Vector3(0,1.26,0),shirt,6)
		b.cone(.21,.16,.16,at+Vector3(0,.85,0),shirt,6)
		b.ellipsoid(Vector3(.16,.11,.16),at+Vector3(0,1.76,.025),Color("513a32"))
	for side: float in [-1,1]:
		b.beam(at+Vector3(side*.12,.86,0),at+Vector3(side*.16,.13,.06),.085,skin if swim else Color("324b55"))
		b.beam(at+Vector3(side*.23,1.35,0),at+Vector3(side*.34,.88,-.04),.065,skin if swim else shirt)


static func _fence(b: RallySampleMeshes,a: Vector3,z: Vector3) -> void:
	var count := ceili(a.distance_to(z)/2.0)
	for i: int in range(count+1):
		var at := a.lerp(z,float(i)/count)
		b.beam(at,at+Vector3.UP*1.15,.055,Color("dee0d2"))
	for height: float in [.5,1.0]: b.beam(a+Vector3.UP*height,z+Vector3.UP*height,.06,Color("718e8a"))


static func _service(land: RallyStageScenery,s: float) -> void:
	var node := _root(land,"MedicalAndMarshals",s,11)
	var b := RallySampleMeshes.new()
	b.box(Vector3(10,.3,12),Vector3(1,-.15,0),Color("777d70"))
	# Original emergency support van: cream body, orange stripe, blue roof lamps.
	b.box(Vector3(2.2,1.6,4.6),Vector3(1,1.25,0),Color("f1ead7"))
	b.box(Vector3(2.22,.24,4.62),Vector3(1,1.22,0),Color("e78d3c"))
	b.box(Vector3(1.9,.6,.05),Vector3(1,1.72,-2.32),Color("477880"))
	for side: float in [-1,1]:
		b.box(Vector3(.03,.6,1.0),Vector3(1+side*1.11,1.72,-1.5),Color("477880"))
		b.box(Vector3(.04,.7,.18),Vector3(1+side*1.13,1.7,.65),Color("2a7a72"))
		b.box(Vector3(.04,.18,.7),Vector3(1+side*1.14,1.7,.65),Color("2a7a72"))
		for axle: float in [-1.45,1.45]: b.ellipsoid(Vector3(.22,.43,.43),Vector3(1+side*1.12,.48,axle),Color("263c40"))
		b.box(Vector3(.35,.15,.32),Vector3(1+side*.65,2.14,-1),Color("3aa7d1"))
	# Freeze the old vehicle collider; the authored van is visual-only.
	var legacy_van := _mesh(node,b,true)
	legacy_van.name="LegacyVanCollisionVisual"
	legacy_van.visible=false
	RallyScreenprintProps.add(node,"medical",Vector3(1,.15,0))
	b=RallySampleMeshes.new()
	# Marshals' high-visibility vests, radio post, small shelter.
	for i: int in range(3):
		var at := Vector3(-2+i*.85,0,3.9)
		_person(b,at,Color("efaa38"))
		b.box(Vector3(.42,.07,.38),at+Vector3(0,1.2,0),Color("f6f1ce"))
	b.beam(Vector3(3,0,4),Vector3(3,3.6,4),.07,Color("4c6666"))
	b.box(Vector3(.9,.65,.12),Vector3(3,2.8,4),Color("e9c64e"))
	_fence(b,Vector3(-4,0,-6),Vector3(-4,0,6))
	_mesh(node,b,true)
	land.spectator_regions.append({"a":node.to_global(Vector3(-2,0,3.9)),"b":node.to_global(Vector3(0,0,3.9))})


static func _arch(land: RallyStageScenery,s: float) -> void:
	var node := _root(land,"PineStoneArch",s,0)
	var b := RallySampleMeshes.new()
	var stone := Color("7b8290")
	# 18m clear span and >9m overhead clearance; craggy natural stone, not a tunnel wall.
	for side: float in [-1,1]:
		b.ellipsoid(Vector3(5,10,6),Vector3(side*15,5,0),stone)
		b.ellipsoid(Vector3(8,6,8),Vector3(side*21,1,2),stone.darkened(.08))
	for i: int in range(11):
		var angle := PI*float(i)/10
		b.ellipsoid(Vector3(3.3,3.1,5),Vector3(cos(angle)*13,8+sin(angle)*7,0),stone.lightened(.06*sin(angle)))
	_mesh(node,b,true)
	for offset: float in [-160,180]:
		var spire := _root(land,"RidgeOutcrop",s+offset,-36)
		var rocks := RallySampleMeshes.new()
		for i: int in range(4): rocks.ellipsoid(Vector3(5+i,10+i*3,6),Vector3(i*5,4+i,0),stone.darkened(i*.03))
		_mesh(spire,rocks)


static func _coast(land: RallyStageScenery) -> void:
	var s := land.route.length-30
	var deck := _root(land,"GoldenCoastOverlook",s,-14)
	deck.position.y += 2.2
	var b := RallySampleMeshes.new()
	b.box(Vector3(18,1,40),Vector3(-4,-.65,-5),Color("d7c5a0"))
	for z: int in range(-24,16,4):
		b.box(Vector3(18,.025,.08),Vector3(-4,-.13,z),Color("ad9e82"))
	_fence(b,Vector3(5,0,-25),Vector3(5,0,15))
	_fence(b,Vector3(-13,0,-25),Vector3(-13,0,15))
	for i: int in range(15): _person(b,Vector3(1-(i%3)*1.4,0,-20+(i/3)*5),[Color("ddad48"),Color("d96b54"),Color("5e9fa0")][i%3])
	_mesh(deck,b,true)
	land.spectator_regions.append({"a":deck.to_global(Vector3(0,0,-21)),"b":deck.to_global(Vector3(0,0,5))})
	var beach := _root(land,"GoldenBeach",s,-55)
	beach.position.y = -24.2
	var sand := RallySampleMeshes.new()
	sand.ellipsoid(Vector3(42,2.2,100),Vector3(0,-1.8,-8),Color("d9ad63"))
	_mesh(beach,sand)
	for i: int in range(9):
		var lounge := Node3D.new()
		lounge.name = "BeachLounge%d"%i
		beach.add_child(lounge)
		lounge.position = Vector3(-5+(i%3)*7,.5,-35+(i/3)*18)
		var sunshade := RallySampleMeshes.new()
		var color: Color = [Color("e58d65"),Color("7dbeb6"),Color("eee1b2")][i%3]
		sunshade.beam(Vector3(1,0,0),Vector3(1,2.5,0),.045,Color("a48860"))
		sunshade.cone(1.6,0,.65,Vector3(1,2.6,0),color,8)
		sunshade.box(Vector3(.8,.08,2),Vector3(-.5,.05,0),color)
		_mesh(lounge,sunshade)
		var person := RallySampleMeshes.new()
		_person(person,Vector3.ZERO,Color("d36c69") if i%2==0 else Color("417b96"),true)
		var figure := _mesh(lounge,person)
		figure.rotation.x = -PI/2
		figure.position = Vector3(-.5,.27,.75)
	# Sailing out across the bay; autonomous decorative motion, no racing interaction.
	for i: int in range(4):
		var boat := _root(land,"DepartingSailboat%d"%i,s+15,-95-i*65)
		boat.position.y = -24.6
		boat.position += -deck.basis.z*float(i*65-50)
		boat.rotation.y += .4+i*.2
		var sail := RallySampleMeshes.new()
		sail.ellipsoid(Vector3(3.2,.8,8),Vector3.ZERO,Color("f2dfb0"))
		sail.beam(Vector3(0,.3,0),Vector3(0,18,0),.1,Color("9e7d52"))
		sail.triangle(Vector3(.1,17.6,0),Vector3(.1,1,-7),Vector3(.1,1,0),Color("fff4d5"))
		sail.triangle(Vector3(-.1,14,0),Vector3(-.1,1,0),Vector3(-.1,1,7),Color("df9d68"))
		_mesh(boat,sail).visible=false
		RallyScreenprintProps.add(boat,"sailboat")
		land.sailboats.append({"node":boat,"origin":boat.position,"direction":-boat.basis.z})


static func _summit(land: RallyStageScenery) -> void:
	var node := _root(land,"SummitBelvedere",land.route.length-30,-14)
	node.position.y += 2.2
	var b := RallySampleMeshes.new()
	b.box(Vector3(17,1,26),Vector3(-3,-.6,0),Color("8e9fa4"))
	_fence(b,Vector3(-11,0,-13),Vector3(-11,0,13))
	_fence(b,Vector3(5,0,-13),Vector3(5,0,13))
	for i: int in range(5): b.ellipsoid(Vector3(1.7-i*.24,.6,1.7-i*.24),Vector3(-5,.4+i*.8,-7),Color("c2bca0"))
	for i: int in range(8): _person(b,Vector3(-2+(i%2)*1.3,0,-10+(i/2)*6),Color("e6b650") if i%2 else Color("617f93"))
	_mesh(node,b,true)
	land.spectator_regions.append({"a":node.to_global(Vector3(-1,0,-10)),"b":node.to_global(Vector3(-1,0,10))})


static func _mesa_overlook(land: RallyStageScenery) -> void:
	var node := _root(land,"MesaOverlook",land.route.length-30,-15)
	node.position.y += 1.6
	var b := RallySampleMeshes.new()
	b.box(Vector3(17,1,28),Vector3(-3,-.6,0),Color("c98a5a"))
	_fence(b,Vector3(-11,0,-14),Vector3(-11,0,14))
	_fence(b,Vector3(5,0,-14),Vector3(5,0,14))
	# Striped shade sails on timber posts, the desert's equivalent of beach umbrellas.
	for i: int in range(3):
		var z := -9.0+i*9
		for corner: Vector2 in [Vector2(-8,-3),Vector2(-1,-3),Vector2(-8,3),Vector2(-1,3)]:
			b.beam(Vector3(corner.x,0,z+corner.y),Vector3(corner.x,3.2,z+corner.y),.08,Color("6b5541"))
		for stripe: int in range(4):
			b.box(Vector3(7.4,.08,1.6),Vector3(-4.5,3.25,z-2.4+stripe*1.6),Color("e7dcc2") if stripe%2 else Color("d2553a"),Vector3(.06,0,0))
	for i: int in range(10): _person(b,Vector3(-2.5+(i%2)*1.3,0,-12+(i/2)*5.5),[Color("e6b650"),Color("3f7a7c"),Color("d96b54")][i%3])
	_mesh(node,b,true)
	land.spectator_regions.append({"a":node.to_global(Vector3(-2,0,-12)),"b":node.to_global(Vector3(-2,0,12))})


static func _corner_markers(land: RallyStageScenery) -> void:
	for note: Dictionary in land.generator.definition.hazard_notes:
		if note.code!="CAUTION_NARROW": continue
		var s := float(note.s)
		var angle := land.route.tangent_at(s-20).signed_angle_to(land.route.tangent_at(s+20),Vector3.UP)
		var inside := -signf(angle)
		if inside==0: inside = -1
		var lateral := inside*(land.route.width_at(s)*.5+1.4)
		var node := _root(land,"CautionRockShoulder",s,lateral)
		var b := RallySampleMeshes.new()
		var stone := Color("a8553a") if land.generator.definition.environment_id=="desert" else Color("7b888a")
		for i: int in range(3): b.ellipsoid(Vector3(.6,.7,.8),Vector3(0,.25,(i-1)*2.4),stone)
		_mesh(node,b,true)

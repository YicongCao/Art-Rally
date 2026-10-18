class_name RallyWildlifeModel
extends RefCounted

const KINDS := ["reindeer","bear","zebra","ostrich","kangaroo"]

static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind.capitalize()
	var b := RallySampleMeshes.new()
	var coat := Color("937457")
	var leg_count := 4
	var hip := .95
	var leg_radius := .065
	match kind:
		"reindeer":
			b.ellipsoid(Vector3(.36,.42,.76),Vector3(0,1.05,0),coat)
			b.ellipsoid(Vector3(.23,.45,.26),Vector3(0,1.5,-.55),Color("b6a28a"))
			b.ellipsoid(Vector3(.21,.22,.36),Vector3(0,1.95,-.73),Color("b6a28a"))
			b.ellipsoid(Vector3(.13,.12,.13),Vector3(0,1.91,-1.02),Color("3c3933"))
			for side: float in [-1,1]:
				b.beam(Vector3(side*.12,2.1,-.55),Vector3(side*.4,2.55,-.4),.035,Color("dfcfac"))
				b.beam(Vector3(side*.4,2.55,-.4),Vector3(side*.65,2.78,-.6),.025,Color("dfcfac"))
				for j: int in range(3):
					var at := Vector3(side*(.25+j*.12),2.32+j*.13,-.45)
					b.beam(at,at+Vector3(side*.08,.23,-.15),.021,Color("dfcfac"))
				b.ellipsoid(Vector3(.18,.07,.1),Vector3(side*.24,2.05,-.58),coat)
		"bear":
			coat=Color("69503f")
			leg_radius=.19
			b.ellipsoid(Vector3(.62,.60,1.05),Vector3(0,1.02,0),coat)
			b.ellipsoid(Vector3(.53,.57,.53),Vector3(0,1.24,-.65),coat.lightened(.05))
			b.ellipsoid(Vector3(.41,.38,.42),Vector3(0,1.18,-1.12),coat)
			b.ellipsoid(Vector3(.23,.19,.29),Vector3(0,1.05,-1.44),Color("b79b7a"))
			b.ellipsoid(Vector3(.13,.10,.08),Vector3(0,1.1,-1.69),Color("242c29"))
			for side: float in [-1,1]: b.ellipsoid(Vector3(.14,.16,.12),Vector3(side*.3,1.53,-1.07),coat)
		"zebra":
			coat=Color("e5dfca")
			_striped(b,Vector3(.43,.47,.86),Vector3(0,1.12,0))
			_striped(b,Vector3(.25,.62,.29),Vector3(0,1.65,-.58))
			_striped(b,Vector3(.23,.25,.47),Vector3(0,2.14,-.87))
			b.ellipsoid(Vector3(.23,.16,.15),Vector3(0,2.04,-1.27),Color("3c3d37"))
			b.box(Vector3(.13,.6,.13),Vector3(0,1.97,-.32),Color("303b39"),Vector3(-.25,0,0))
			b.beam(Vector3(0,1.2,.78),Vector3(0,.7,1.2),.045,Color("303b39"))
			for side: float in [-1,1]: b.ellipsoid(Vector3(.08,.24,.10),Vector3(side*.18,2.43,-.66),coat)
		"ostrich":
			coat=Color("a6947e")
			leg_count=2
			hip=1.3
			b.ellipsoid(Vector3(.52,.55,.77),Vector3(0,1.56,.12),Color("39403b"))
			for side: float in [-1,1]: b.ellipsoid(Vector3(.16,.32,.6),Vector3(side*.47,1.55,.2),Color("eee5cc"))
			b.beam(Vector3(0,1.8,-.43),Vector3(0,2.75,-.65),.11,coat)
			b.ellipsoid(Vector3(.17,.18,.22),Vector3(0,2.81,-.68),coat)
			b.beam(Vector3(0,2.8,-.82),Vector3(0,2.78,-1.07),.09,Color("d3a76d"))
			b.ellipsoid(Vector3(.3,.23,.4),Vector3(0,1.9,.75),Color("eee5cc"))
		"kangaroo":
			coat=Color("b88759")
			leg_count=2
			hip=.7
			leg_radius=.13
			b.ellipsoid(Vector3(.37,.62,.35),Vector3(0,1.02,0),coat,Vector3(.3,0,0))
			b.ellipsoid(Vector3(.25,.42,.21),Vector3(0,1.65,-.26),coat)
			b.ellipsoid(Vector3(.19,.21,.32),Vector3(0,2.02,-.42),coat)
			b.ellipsoid(Vector3(.18,.45,.15),Vector3(0,1.1,-.28),Color("dcc3a0"))
			b.beam(Vector3(0,.70,.24),Vector3(0,.25,1.05),.17,coat)
			b.beam(Vector3(0,.25,1.05),Vector3(0,.10,1.8),.09,coat)
			for side: float in [-1,1]:
				b.ellipsoid(Vector3(.08,.32,.09),Vector3(side*.14,2.37,-.33),coat,Vector3(0,0,-side*.2))
				b.beam(Vector3(side*.25,1.5,-.17),Vector3(side*.28,1.0,-.54),.055,coat)
				b.ellipsoid(Vector3(.24,.39,.3),Vector3(side*.29,.65,.12),coat)
	# Eyes on the sides of the head keep silhouettes readable without cartoon billboards.
	var eye_height: float = {"reindeer":2.02,"bear":1.29,"zebra":2.22,"ostrich":2.88,"kangaroo":2.08}[kind]
	var eye_z: float = {"reindeer":-.86,"bear":-1.38,"zebra":-1.02,"ostrich":-.77,"kangaroo":-.55}[kind]
	var eye_x: float = .34 if kind=="bear" else .17
	for side: float in [-1,1]: b.ellipsoid(Vector3(.035,.04,.04),Vector3(side*eye_x,eye_height,eye_z),Color("202c2b"))
	RallyStageLandmarks._mesh(root,b)
	var legs: Array[Node3D] = []
	for i: int in range(leg_count):
		var leg := Node3D.new()
		leg.position=Vector3((-.27 if i%2==0 else .27),hip,(-.48 if i<2 else .48) if leg_count==4 else .05)
		root.add_child(leg)
		legs.append(leg)
		var limb := RallySampleMeshes.new()
		limb.beam(Vector3.ZERO,Vector3(0,-hip+.16,.08),leg_radius,coat)
		if kind=="zebra":
			for band: int in range(4): limb.box(Vector3(.14,.10,.14),Vector3(0,-.16-band*.18,.04),Color("35413e"))
		limb.box(Vector3(leg_radius*2.3,.13,.48 if kind=="kangaroo" else .23),Vector3(0,-hip+.1,-.1),Color("403e34"))
		RallyStageLandmarks._mesh(leg,limb)
	root.set_meta("legs",legs)
	return root

static func _striped(b: RallySampleMeshes,size: Vector3,at: Vector3) -> void:
	# More color subdivisions than the silhouette mesh: narrow wrapping stripes,
	# not a single black/white color per coarse triangle (which reads as a cow).
	var sphere := SphereMesh.new()
	sphere.radius=1
	sphere.height=2
	sphere.radial_segments=48
	sphere.rings=20
	var arrays := sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for i: int in range(0,indices.size(),3):
		var a := vertices[indices[i]]*size+at
		var c := vertices[indices[i+1]]*size+at
		var d := vertices[indices[i+2]]*size+at
		var center := (a+c+d)/3
		var stripe := sin(center.z*26+center.y*5+absf(center.x)*3)>.05
		b.triangle(a,c,d,Color("35413e") if stripe else Color("e5dfca"))

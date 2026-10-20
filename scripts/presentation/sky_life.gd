class_name RallySkyLife
extends Node3D

var birds: Array[Dictionary] = []
var balloons: Array[Dictionary] = []
var clock: float = 0

func build(land: RallyStageScenery) -> void:
	name = "LivingSky"
	var rng := RandomNumberGenerator.new()
	rng.seed = land.generator.definition.seed_value+883
	var count := 12 if land.generator.definition.environment_id=="coast" else 9
	for i: int in range(count):
		var node := Node3D.new()
		node.name = "Balloon%d"%i
		add_child(node)
		var station := land.route.length*(.08+.84*float(i)/float(count-1))
		var bank_side := -1.0 if i%2==0 else 1.0
		var at := land.route.position_at(station)+land.route.rights[land.route.index_at(station)]*bank_side*rng.randf_range(190,380)
		at += land.route.tangent_at(station)*rng.randf_range(-45,45)
		at.y = maxf(land.height_at(at.x,at.z),land.route.position_at(station).y)+rng.randf_range(75,150)
		for attempt: int in range(16):
			var crowded := false
			for existing: Dictionary in balloons:
				if at.distance_to(existing.origin)<190: crowded = true
			if not crowded: break
			at += land.route.rights[land.route.index_at(station)]*bank_side*75+Vector3.UP*8
		node.position = at
		node.scale=Vector3.ONE*1.35
		var b := RallySampleMeshes.new()
		var ink: Color = [Color("c96b48"),Color("d6b665"),Color("528d92"),Color("a05e6e")][i%4]
		for sector: int in range(12):
			for ring: int in range(7):
				var vertices: Array[Vector3] = []
				for uv: Vector2 in [Vector2(sector,ring),Vector2(sector+1,ring),Vector2(sector,ring+1),Vector2(sector,ring+1),Vector2(sector+1,ring),Vector2(sector+1,ring+1)]:
					var angle := uv.x*TAU/12
					var phi := .22+uv.y*2.70/7
					vertices.append(Vector3(sin(phi)*cos(angle)*6,cos(phi)*8+10,sin(phi)*sin(angle)*6))
				for t: int in [0,3]: b.triangle(vertices[t],vertices[t+1],vertices[t+2],ink if sector%3 else Color("f1d9a1"))
		b.box(Vector3(2.1,1.3,1.6),Vector3(0,.65,0),Color("806949"))
		for side: float in [-1,1]:
			for z: float in [-.7,.7]: b.beam(Vector3(side*.9,1.2,z),Vector3(side*1.5,3.2,z),.045,Color("594f42"))
		var legacy := RallyStageLandmarks._mesh(node,b)
		var authored := RallyScreenprintProps.add(node,"balloon")
		if authored!=null: legacy.queue_free()
		balloons.append({"node":node,"origin":at,"phase":rng.randf_range(0,TAU)})
	if land.generator.definition.environment_id=="autumn": return
	# Shared group phase keeps each loose formation together, instead of unrelated solo birds.
	for flock: int in range(3):
		var s := land.route.length*(.18+flock*.31)
		var group_phase := rng.randf_range(0,TAU)
		var flock_size := rng.randi_range(5,6)
		var origin := land.route.position_at(s)+land.route.rights[land.route.index_at(s)]*-160
		origin.y = maxf(origin.y,land.height_at(origin.x,origin.z))+75
		for i: int in range(flock_size):
			var node := Node3D.new()
			node.name = "SeagullFlock%d_%d"%[flock,i]
			add_child(node)
			var wings: Array[Node3D] = []
			for side: float in [-1,1]:
				var pivot := Node3D.new()
				node.add_child(pivot)
				var b := RallySampleMeshes.new()
				# A pair of tapered brush strokes; no sculpted head, beak or bulky body.
				b.triangle(Vector3(0,0,-.22),Vector3(side*.85,.42,.1),Vector3(0,0,.20),Color("58777b"))
				b.triangle(Vector3(side*.85,.42,.1),Vector3(side*1.9,.10,.52),Vector3(side*.58,.30,.36),Color("496970"))
				var mesh := RallyStageLandmarks._mesh(pivot,b)
				var material := StandardMaterial3D.new()
				material.vertex_color_use_as_albedo = true
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.material_override = material
				wings.append(pivot)
			var offset := Vector3((i%2*2-1)*(i/2+1)*4.5,i*.55,i*4.2)
			birds.append({"node":node,"origin":origin+offset,"wings":wings,"phase":group_phase,"wing_phase":i*.65,"direction":land.route.rights[land.route.index_at(s)]})

func advance(dt: float) -> void:
	clock += dt
	for balloon: Dictionary in balloons:
		balloon.node.position = balloon.origin+Vector3.UP*sin(clock*.23+balloon.phase)*2.5
	for bird: Dictionary in birds:
		var phase: float = clock*.018+bird.phase
		bird.node.position = bird.origin+bird.direction*sin(phase)*190+Vector3.UP*sin(clock*.4+bird.phase)*2
		bird.node.rotation.y = atan2(-bird.direction.x,-bird.direction.z)+(0 if cos(phase)>0 else PI)
		for i: int in range(2): bird.wings[i].rotation.z = sin(clock*2.8+bird.wing_phase)*.23*(1 if i==0 else -1)

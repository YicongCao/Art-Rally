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
		var at := land.route.position_at(station)+land.route.rights[land.route.index_at(station)]*bank_side*rng.randf_range(330,650)
		at += land.route.tangent_at(station)*rng.randf_range(-45,45)
		at.y = maxf(land.height_at(at.x,at.z),land.route.position_at(station).y)+rng.randf_range(100,230)
		for attempt: int in range(16):
			var crowded := false
			for existing: Dictionary in balloons:
				if at.distance_to(existing.origin)<240: crowded = true
			if not crowded: break
			at += land.route.rights[land.route.index_at(station)]*bank_side*130+Vector3.UP*12
		node.position = at
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
		RallyStageLandmarks._mesh(node,b)
		balloons.append({"node":node,"origin":at,"phase":rng.randf_range(0,TAU)})
	if land.generator.definition.environment_id=="autumn": return
	for i: int in range(10):
		var node := Node3D.new()
		node.name = "DistantSeagull%d"%i
		add_child(node)
		var s := land.route.length*(.23 if i<5 else .73)
		var at := land.route.position_at(s)+land.route.rights[land.route.index_at(s)]*(-160-i*8)+Vector3.UP*(35+i*3)
		var body := RallySampleMeshes.new()
		body.ellipsoid(Vector3(.26,.23,.8),Vector3.ZERO,Color("e8e7d8"))
		body.cone(.12,0,.35,Vector3(0,0,-.85),Color("d5a64d"),5)
		RallyStageLandmarks._mesh(node,body)
		var wings: Array[Node3D] = []
		for side: float in [-1,1]:
			var pivot := Node3D.new()
			node.add_child(pivot)
			var b := RallySampleMeshes.new()
			b.triangle(Vector3(0,.1,-.25),Vector3(side*2.4,0,.65),Vector3(side*.8,0,-.2),Color("e1e4da"))
			b.triangle(Vector3(side*2.4,0,.65),Vector3(side*1.8,0,.4),Vector3(side*1.8,0,.8),Color("475f66"))
			RallyStageLandmarks._mesh(pivot,b)
			wings.append(pivot)
		birds.append({"node":node,"origin":at,"wings":wings,"phase":rng.randf_range(0,TAU),"direction":land.route.rights[land.route.index_at(s)]})

func advance(dt: float) -> void:
	clock += dt
	for balloon: Dictionary in balloons:
		balloon.node.position = balloon.origin+Vector3.UP*sin(clock*.23+balloon.phase)*2.5
	for bird: Dictionary in birds:
		var phase: float = clock*.018+bird.phase
		bird.node.position = bird.origin+bird.direction*sin(phase)*190+Vector3.UP*sin(clock*.4+bird.phase)*2
		bird.node.rotation.y = atan2(-bird.direction.x,-bird.direction.z)+(0 if cos(phase)>0 else PI)
		for i: int in range(2): bird.wings[i].rotation.z = sin(clock*3.4+bird.phase)*.26*(1 if i==0 else -1)

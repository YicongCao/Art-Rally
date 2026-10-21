class_name RallySkyLife
extends Node3D

var birds: Array[Dictionary] = []
var balloons: Array[Dictionary] = []
var clock: float = 0
var flocks: Array[Dictionary] = []
var last_progress: float = 0

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
	# Authored birds, distance-triggered once per pass: close enough to read in chase view.
	for flock: int in range(3):
		var station := land.route.length*(.18+flock*.31)
		var path := _flight_path(land,station)
		# Prefer a nearby vista with clear sight lines, not a flight behind the ridge.
		if land.generator.definition.environment_id=="highland":
			var best := _visibility_score(land,station,path)
			var anchor := station
			for offset: int in [-100,-80,-60,-40,-20,20,40,60,80,100]:
				var candidate := anchor+offset
				var flight := _flight_path(land,candidate)
				var score := _visibility_score(land,candidate,flight)
				if score>best:
					best=score;station=candidate;path=flight
		var from: Vector3=path[0]
		var to: Vector3=path[1]
		var entries: Array[Dictionary] = []
		for i: int in range(6):
			var node: Node3D=load("res://assets/screenprint/props/sky_bird.glb").instantiate()
			node.name="SkyBird%d_%d"%[flock,i]
			add_child(node)
			node.visible=false
			node.scale=Vector3.ONE*1.1
			# Preserve soft painted materials, no vehicle outline shader on wildlife.
			for part: Node in node.find_children("*","MeshInstance3D",true,false):
				part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for surface: int in range(part.mesh.get_surface_count()):
					var material := part.mesh.surface_get_material(surface) as StandardMaterial3D
					if material!=null: material.cull_mode=BaseMaterial3D.CULL_DISABLED
			var entry := {"node":node,"meshes":node.find_children("*","MeshInstance3D",true,false),"wings":[node.find_child("WingLeft",true,false),node.find_child("WingRight",true,false)],"offset":Vector3((1 if i%2==0 else -1)*(i/2)*3.0,i*.45,i*2.4),"wing_phase":i*.7}
			entries.append(entry)
			birds.append(entry)
		flocks.append({"station":station,"from":from,"to":to,"time":-1.0,"done":false,"birds":entries})

func _flight_path(land: RallyStageScenery,station: float) -> PackedVector3Array:
	var pose := land.route.pose_at(station+38,0)
	var side := land.generator.definition.mountain_side_at(station+38)
	var from: Vector3= pose.origin+pose.basis.x*(-48 if absf(side)<.1 else signf(side)*9)
	var to: Vector3= pose.origin+pose.basis.x*(95 if absf(side)<.1 else -signf(side)*95)-pose.basis.z*55
	var altitude := pose.origin.y+22
	for sample: int in range(13):
		var p: Vector3=from.lerp(to,float(sample)/12)
		altitude=maxf(altitude,land.rendered_height_at(p.x,p.z)+8)
	from.y=altitude; to.y=altitude+6
	return PackedVector3Array([from,to])

func _visibility_score(land: RallyStageScenery,station: float,path: PackedVector3Array) -> int:
	var pose := land.route.pose_at(station-40,0)
	var eye := pose.origin+pose.basis.z*8+Vector3.UP*4
	var forward := (land.route.position_at(station+10)-eye).normalized()
	var score := 0
	for t: float in [.12,.24,.36,.48,.60,.72]:
		var target := path[0].lerp(path[1],t)+Vector3.UP*3
		if (target-eye).normalized().dot(forward)<.80: continue
		var clear := true
		for sample: int in range(1,20):
			var p := eye.lerp(target,sample/20.0)
			if land.rendered_height_at(p.x,p.z)+1>p.y: clear=false;break
		if clear: score+=1
	return score

func reset_flights() -> void:
	for flock: Dictionary in flocks:
		flock.time=-1.0; flock.done=false
		for bird: Dictionary in flock.birds: bird.node.hide()

func advance(dt: float,progress: float = -1) -> void:
	clock += dt
	for balloon: Dictionary in balloons:
		balloon.node.position = balloon.origin+Vector3.UP*sin(clock*.23+balloon.phase)*2.5
	if progress>=0:
		if progress<30 and last_progress>100: reset_flights()
		last_progress=progress
	for flock: Dictionary in flocks:
		if flock.done: continue
		if flock.time<0:
			if progress<flock.station-65 or progress>flock.station+45: continue
			flock.time=0.0
		flock.time+=dt
		var t: float=flock.time/26.0
		if t>=1:
			flock.done=true
			for bird: Dictionary in flock.birds: bird.node.hide()
			continue
		var direction: Vector3=(flock.to-flock.from).normalized()
		for bird: Dictionary in flock.birds:
			var node: Node3D=bird.node
			node.show()
			node.position=flock.from.lerp(flock.to,t)+bird.offset+Vector3.UP*sin(t*PI)*4
			node.rotation.y=atan2(-direction.x,-direction.z)
			# Long glides punctuated by two soft wingbeats, never frantic flapping.
			var flap := sin(clock*4.4+bird.wing_phase)*.34*(.25+.75*smoothstep(-.4,.6,sin(clock*.65)))
			for wing: int in range(2): bird.wings[wing].rotation.z=flap*(1 if wing==0 else -1)
			var fade := smoothstep(0,.8,flock.time)*(1-smoothstep(22,26,flock.time))
			for part: MeshInstance3D in bird.meshes: part.transparency=1-fade

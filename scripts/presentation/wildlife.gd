class_name RallyWildlife
extends Node3D

var scene: Node3D
var events: Array[Dictionary] = []
var next_event: int = 0
var active: bool = false
var elapsed: float = 0
var deer := Node3D.new()
var legs: Array[Node3D] = []
var hooves := AudioStreamPlayer3D.new()
var station: float = 0
var side: float = 1

func build(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "CrossingReindeer"
	if scene.challenge.stage.environment_id=="coast": return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := rng.randi_range(2,3)
	for i: int in range(count):
		var distance: float = scene.generator.route.length*((i+1.0)/(count+1.0)+rng.randf_range(-.035,.035))
		for river: Vector3 in scene.challenge.stage.river_crossings:
			if absf(distance-river.x)<110: distance=river.x+120
		events.append({"s":distance,"side":-1.0 if rng.randf()<.5 else 1.0})
	add_child(deer)
	var b := RallySampleMeshes.new()
	b.ellipsoid(Vector3(.36,.42,.76),Vector3(0,1.05,0),Color("88705a"))
	b.ellipsoid(Vector3(.23,.45,.26),Vector3(0,1.5,-.55),Color("b6a28a"))
	b.ellipsoid(Vector3(.21,.22,.36),Vector3(0,1.95,-.73),Color("b6a28a"))
	b.ellipsoid(Vector3(.13,.12,.13),Vector3(0,1.91,-1.02),Color("3c3933"))
	for direction: float in [-1,1]:
		b.beam(Vector3(direction*.12,2.1,-.55),Vector3(direction*.40,2.55,-.4),.035,Color("dfcfac"))
		b.beam(Vector3(direction*.4,2.55,-.4),Vector3(direction*.65,2.78,-.6),.025,Color("dfcfac"))
		for j: int in range(3):
			var at := Vector3(direction*(.25+j*.12),2.32+j*.13,-.45)
			b.beam(at,at+Vector3(direction*.08,.23,-.15),.021,Color("dfcfac"))
		b.ellipsoid(Vector3(.18,.07,.1),Vector3(direction*.24,2.05,-.58),Color("88705a"))
	RallyStageLandmarks._mesh(deer,b)
	for i: int in range(4):
		var leg := Node3D.new()
		leg.position = Vector3((-.23 if i%2==0 else .23),.95,(-.48 if i<2 else .48))
		deer.add_child(leg)
		legs.append(leg)
		var mesh := RallySampleMeshes.new()
		mesh.beam(Vector3.ZERO,Vector3(0,-.83,.05),.065,Color("675746"))
		mesh.box(Vector3(.13,.12,.2),Vector3(0,-.88,0),Color("373a35"))
		RallyStageLandmarks._mesh(leg,mesh)
	hooves.stream = RallyAudioDirector.asset("hooves",true)
	hooves.bus = "Environment"
	hooves.unit_size = 22
	hooves.max_distance = 130
	hooves.volume_db = -5
	deer.add_child(hooves)
	deer.hide()

func reset() -> void:
	next_event = 0
	active = false
	deer.hide()
	hooves.stop()

func advance(dt: float) -> void:
	if events.is_empty(): return
	if scene.session.phase!=RallyStageSession.Phase.RUNNING:
		deer.hide()
		hooves.stop()
		return
	var progress: float = scene.session.progress
	if not active and next_event<events.size() and progress>=float(events[next_event].s)-maxf(100,scene.vehicle.linear_velocity.length()*5.5):
		station = events[next_event].s
		side = events[next_event].side
		next_event+=1
		# Recovery/teleport must never materialize an animal immediately in front of the car.
		if station-progress>35:
			active = true
			elapsed = 0
			deer.show()
			if DisplayServer.get_name()!="headless": hooves.play()
	if not active: return
	elapsed+=dt
	var across := side*lerpf(-22,32,clampf(elapsed/7,0,1))
	var route: RallyStageRoute = scene.generator.route
	var position_on_route := route.position_at(station)
	var right := route.rights[route.index_at(station)]
	var at := position_on_route+right*across
	at.y = scene.presentation.scenery.height_at(at.x,at.z)
	if absf(across)<route.width_at(station)*.5: at.y=position_on_route.y
	deer.position = at+Vector3.UP*(absf(sin(elapsed*9))*.10)
	deer.rotation.y = atan2(-right.x*side,-right.z*side)
	for i: int in range(4): legs[i].rotation.x=sin(elapsed*9+(0 if i in [0,3] else PI))*.6
	hooves.volume_linear = .6*smoothstep(0,.7,elapsed)*(1-smoothstep(5.7,7,elapsed))
	if elapsed>=7:
		active = false
		deer.hide()
		hooves.stop()


func _exit_tree() -> void:
	# Coast has no wildlife mesh; release the preallocated, unparented helpers too.
	if is_instance_valid(hooves):
		hooves.stop()
		hooves.stream=null
		if hooves.get_parent()==null: hooves.free()
	if is_instance_valid(deer) and deer.get_parent()==null: deer.free()

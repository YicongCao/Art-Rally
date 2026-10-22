class_name RallyWildlife
extends Node3D

var scene: Node3D
var events: Array[Dictionary] = []
var next_event: int = 0
var active: bool = false
var elapsed: float = 0
var deer := Node3D.new()
var legs: Array[Node3D] = []
var skins: Dictionary = {}
var kind: String = "reindeer"
const CROSSING_DURATION := 24.0
var fade: float = 0
var hooves := AudioStreamPlayer3D.new()
var station: float = 0
var side: float = 1

func build(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "CrossingWildlife"
	if scene.challenge.stage.environment_id in ["coast","highland"]: return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := rng.randi_range(2,3)
	var kinds: Array = RallyWildlifeModel.KINDS.duplicate()
	# Only arid-country animals cross the red desert.
	if scene.challenge.stage.environment_id=="desert": kinds = ["kangaroo","ostrich","kangaroo"]
	kinds.shuffle()
	for i: int in range(count):
		var distance: float = scene.generator.route.length*((i+1.0)/(count+1.0)+rng.randf_range(-.035,.035))
		for river: Vector3 in scene.challenge.stage.river_crossings:
			if absf(distance-river.x)<110: distance=river.x+120
		events.append({"s":distance,"side":-1.0 if rng.randf()<.5 else 1.0,"kind":kinds[i]})
	add_child(deer)
	for species: String in RallyWildlifeModel.KINDS:
		var skin := RallyWildlifeModel.build(species)
		deer.add_child(skin)
		skins[species]=skin
		skin.hide()
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
	if not active and next_event<events.size() and progress>=float(events[next_event].s)-maxf(100,scene.vehicle.linear_velocity.length()*8.5):
		station = events[next_event].s
		side = events[next_event].side
		kind = events[next_event].get("kind","reindeer")
		for species: String in skins: skins[species].visible=species==kind
		legs.assign(skins[kind].get_meta("legs"))
		next_event+=1
		# Recovery/teleport must never materialize an animal immediately in front of the car.
		if station-progress>35:
			active = true
			elapsed = 0
			deer.show()
			if DisplayServer.get_name()!="headless": hooves.play()
	if not active: return
	elapsed+=dt
	var across := side*lerpf(-55,95,clampf(elapsed/CROSSING_DURATION,0,1))
	var route: RallyStageRoute = scene.generator.route
	var position_on_route := route.position_at(station)
	var right := route.rights[route.index_at(station)]
	var at := position_on_route+right*across
	at.y = scene.presentation.scenery.height_at(at.x,at.z)
	if absf(across)<route.width_at(station)*.5: at.y=position_on_route.y
	var hop := hop_height(elapsed) if kind=="kangaroo" else absf(sin(elapsed*9))*.08
	deer.position = at+Vector3.UP*hop
	deer.rotation.y = atan2(-right.x*side,-right.z*side)
	for i: int in range(legs.size()):
		legs[i].rotation.x=sin(elapsed*(TAU/0.85 if kind=="kangaroo" else 9)+(0 if kind=="kangaroo" or i in [0,3] else PI))*(.32 if kind=="bear" else .6)
	# Full 150 m traversal: leave the road, recede into the scenery, then fade.
	# Transparency reaches one BEFORE visibility changes, never a seven-second pop.
	fade = maxf(1-smoothstep(0,1.2,elapsed),smoothstep(19,CROSSING_DURATION,elapsed))
	for mesh: Node in skins[kind].find_children("*","MeshInstance3D",true,false): mesh.transparency=fade
	hooves.pitch_scale = .7 if kind=="bear" else (1.2 if kind=="ostrich" else 1.0)
	hooves.volume_linear = .6*(1-fade)*(1-smoothstep(22,95,absf(across)))
	if kind=="kangaroo": hooves.volume_linear*=1-smoothstep(.05,.25,hop)
	if elapsed>=CROSSING_DURATION:
		active = false
		deer.hide()
		hooves.stop()

static func hop_height(time: float) -> float:
	var phase := fposmod(time,.85)/.85
	return .95*4*phase*(1-phase)



func _exit_tree() -> void:
	# Coast has no wildlife mesh; release the preallocated, unparented helpers too.
	if is_instance_valid(hooves):
		hooves.stop()
		hooves.stream=null
		if hooves.get_parent()==null: hooves.free()
	if is_instance_valid(deer) and deer.get_parent()==null: deer.free()

extends "res://tests/test_suite.gd"

func frame(t: float,p: Vector3) -> Array:
	return [t,p.x,p.y,p.z,0,0,0,1,0,0,0,0,0,.35,.35,.35,.35]

func _run() -> void:
	var data := {"duration":.1,"frames":[frame(0,Vector3.ZERO),frame(1.0/30,Vector3(1,0,0)),frame(2.0/30,Vector3(2,0,.2)),frame(.1,Vector3(3,0,.6))],"gaps":[]}
	var t := 1.0/30
	var a: Transform3D = RallyGhostRecording.sample(data,t-.0001).pose
	var b: Transform3D = RallyGhostRecording.sample(data,t).pose
	var c: Transform3D = RallyGhostRecording.sample(data,t+.0001).pose
	check(((b.origin-a.origin)/.0001).distance_to((c.origin-b.origin)/.0001)<.15,"Replay velocity is continuous at sample boundaries")
	check(b.origin.is_equal_approx(Vector3(1,0,0)),"Smooth replay still passes through recorded positions")
	data.gaps = [[.04,.07]]
	check(RallyGhostRecording.sample(data,.055).is_empty(),"Smoothing cannot bridge recovery gaps")
	check(not RallyGhostRecording._continuous(data,0,.1),"Recovery discontinuity cannot contribute a tangent")
	check(RallyGhostRecording.unwrap_spin(6.2,.1,5.5,1.0/30)>6.2,"Wheel wrap cannot briefly spin a replay wheel backwards")
	check(is_equal_approx(RallyGhostRecording.unwrap_spin(0,4.0,120,1.0/30),4.0),"Fast wheels preserve turns larger than pi per sample")
	var wheel_data := {"duration":.04,"frames":[frame(0,Vector3.ZERO),frame(.04,Vector3.ONE)],"gaps":[]}
	wheel_data.frames[0][9] = 6.2
	wheel_data.frames[1][9] = .1
	check(absf(sin(RallyGhostRecording.sample(wheel_data,.02).spins[0]))<.05,"Legacy wrapped wheel recordings interpolate across the angle seam")
	check(is_equal_approx(RallyGameSettings.DEFAULTS.music_volume,.45*1.3),"Default music gain increases by 30 percent")
	check(RallyPlateText.font().base_font==RallyFonts.DISPLAY,"Plate and title share the display font with Chinese fallback")
	for id: String in RallyContentCatalog.STAGES:
		var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
		app.profile.path = "user://cinematic-test-%d/profile.json"%Time.get_ticks_usec()
		root.add_child(app)
		app.profile.data = RallyProfileStore.fresh()
		app.chosen_stage = id
		await app.start_race()
		var scene: Node3D = app.race
		var route: RallyStageRoute = scene.generator.route
		await ticks(2)
		var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
		for river: Vector3 in scene.challenge.stage.river_crossings:
			var aligned := true
			for offset: float in [-river.y*.5,0,river.y*.5]:
				var p := route.position_at(river.x+offset)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP*2,1))
				aligned = aligned and not hit.is_empty() and absf(hit.position.y-p.y)<.025
			var bridge: Node3D = scene.presentation.scenery.dressing.get_node("RiverBridge%d"%river.x)
			check(aligned and bridge.position.distance_to(route.position_at(river.x))<.001,id+" bridge geometry and raised physical roadway share their origin")
		var points: Array = scene.presentation.sky_life.balloons
		var minimum := INF
		for i: int in range(points.size()):
			for j: int in range(i+1,points.size()): minimum=minf(minimum,points[i].origin.distance_to(points[j].origin))
		check(minimum>140,id+" balloons have generous separation across the landscape")
		var heli: RallyBroadcastHelicopter = scene.broadcast
		heli.photos_enabled = false
		scene.session.phase = RallyStageSession.Phase.RUNNING
		scene.session.progress = route.length*.95
		heli.advance(1)
		for i: int in range(13): heli.advance(1)
		check(heli.next_pass==1 and not heli.airframe.visible,id+" passing several trigger distances cannot cause back-to-back helicopters")
		for i: int in range(35): heli.advance(1)
		check(heli.next_pass==2,id+" next helicopter waits for its cooldown")
		if id=="sunlit_cape":
			var beacon: Node3D = scene.presentation.scenery.dressing.find_children("*","RallyLighthouseBeacon",true,false)[0]
			var heading := beacon.rotation.y
			beacon._process(1)
			check(beacon.rotation.y>heading,"Lighthouse spotlight rotates")
		await app.leave_race()
		app.free()
		await process_frame
	finish()

extends "res://tests/test_suite.gd"
func _run() -> void:
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://world-details-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.audio.apply_settings(app.prefs)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Road"))),float(app.prefs.values.road_volume)*.6),"Road mix is 60% of the saved slider level")
	await app.start_race()
	var scene: Node3D=app.race
	check(scene.presentation.checkpoints.root.has_node("StartArch") and scene.presentation.checkpoints.root.has_node("FinishArch"),"Both timing boundaries have checkered inflatable arches")
	check(scene.wildlife.skins.size()==5,"Five distinct wildlife models are available")
	check(RallyWildlife.hop_height(0)==0 and RallyWildlife.hop_height(.425)>.9 and RallyWildlife.hop_height(.85)<.001,"Kangaroo has a grounded landing and a visible airborne apex")
	for kind: String in RallyWildlifeModel.KINDS:
		scene.wildlife.reset()
		scene.wildlife.events[0].kind=kind
		scene.session.phase=RallyStageSession.Phase.RUNNING
		scene.session.progress=scene.wildlife.events[0].s-100
		scene.wildlife.advance(9)
		check(scene.wildlife.active and scene.wildlife.skins[kind].visible and scene.wildlife.fade==0,kind+" stays visible across the road")
		var crossing: Vector3=scene.wildlife.deer.position
		scene.wildlife.advance(12)
		check(scene.wildlife.active and scene.wildlife.fade>0 and scene.wildlife.fade<1 and scene.wildlife.deer.position.distance_to(crossing)>60,kind+" recedes over 60 metres before fading")
		scene.wildlife.advance(3)
		check(not scene.wildlife.active and scene.wildlife.fade==1 and not scene.wildlife.hooves.playing,kind+" retires only after a complete fade")
	scene.broadcast.reset()
	scene.session.progress=scene.generator.route.length*.17
	scene.broadcast.advance(4)
	check(is_equal_approx(scene.broadcast.rotor_audio.volume_linear,.75),"Rotor envelope peak is 150% of the old 0.5 gain")
	var pass_count: int=scene.broadcast.next_pass
	scene.broadcast.advance(13)
	scene.session.progress=scene.generator.route.length*.9
	scene.broadcast.advance(1)
	check(scene.broadcast.next_pass==pass_count,"Helicopter still respects the quiet interval between passes")
	check(RallyContentCatalog.challenge("sunset_ridge","F160").rules_version=="time-trial-4","New penalty rules isolate old best times and ghosts")
	# Exercise the live challenge hook: a missed gate adds a ghost timeline gap.
	paused=false
	scene.respawn_wait=false
	scene.session.restart()
	scene.session.phase=RallyStageSession.Phase.RUNNING
	scene.session.next_gate=1
	scene.session.elapsed=10
	var route: RallyStageRoute=scene.generator.route
	var offset := route.rights[route.index_at(126)]*10
	scene.session.projection_hint=route.index_at(126)
	scene.session.previous=route.position_at(125)+offset
	scene.vehicle.position=route.position_at(126)+offset+Vector3.UP*.6
	scene.vehicle.linear_velocity=route.tangent_at(126)*10
	scene.trajectory.reset()
	scene.trajectory.capture(10,scene.vehicle,true)
	scene._physics_process(.1)
	check(scene.session.penalty==5 and scene.session.next_gate==2,"Live challenge automatically advances a missed balloon")
	check(scene.trajectory.gaps.size()==1 and is_equal_approx(scene.trajectory.gaps[0][1]-scene.trajectory.gaps[0][0],5),"Five-second miss is recorded as a ghost timeline gap")
	check(not scene.session.gate_times.is_empty() and is_equal_approx(scene.session.gate_times[-1],scene.session.total_time()),"Missed gate split includes its penalty")
	# Miss the penultimate gate and cross the finish in one update: the stored
	# result must already contain the gap when completed is emitted.
	scene.session.next_gate=scene.session.gates.size()-2
	scene.session.elapsed=120
	scene.session.split_times.assign([35.0,80.0])
	var finish_s: float=scene.session.gates[-1]
	scene.session.projection_hint=route.index_at(finish_s)
	scene.session.previous=route.position_at(finish_s-1)
	scene.vehicle.position=route.position_at(finish_s+1)
	scene.vehicle.basis=route.pose_at(finish_s).basis
	scene._physics_process(.1)
	check(scene.session.phase==RallyStageSession.Phase.FINISHED and scene.trajectory.gaps.size()==2,"Finish-tick miss is recorded before the final trajectory is captured")
	check(app.profile.load_ghost(scene.challenge).get("gaps",[]).size()==2,"Saved best ghost already includes the finish-tick penalty gap")
	await app.leave_race()
	app.free()
	await process_frame
	finish()

extends "res://tests/test_suite.gd"

func _run() -> void:
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	app.profile.path = "user://replay-test-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data = RallyProfileStore.fresh()
	app.chosen_vehicle = "R200"
	await app.start_race()
	var scene: Node3D = app.race
	var frames: Array = []
	for i: int in range(181):
		var time := i/30.0
		var pose: Transform3D = scene.generator.route.pose_at(120+time*13,.68)
		var q := pose.basis.get_rotation_quaternion()
		var frame := [time,pose.origin.x,pose.origin.y,pose.origin.z,q.x,q.y,q.z,q.w,0.0]
		for wheel: int in range(4): frame.append(time*30)
		for wheel: int in range(4): frame.append(.35)
		frames.append(frame)
	var payload := {"version":1,"complete":true,"duration":6.0,"key":scene.challenge.key(),"frames":frames,"gaps":[[2.0,4.0]]}
	var result := {"elapsed":4.0,"penalty":2.0,"total_time":6.0,"splits":[2.0,4.0,6.0],"source":"human_keyboard","practice":false,"reset_count":1}
	var outcome := app.profile.record(scene.challenge,result,payload)
	check(outcome.get("saved",false) and outcome.get("new_best",false),"Eligible new best and ghost persist together")
	var restored := RallyProfileStore.new()
	restored.path = app.profile.path
	restored.load_file()
	var stored := restored.load_ghost(scene.challenge)
	check(stored.frames.size()==181 and RallyGameSettings.DEFAULTS.ghost,"Compatible fastest ghost reloads and is enabled by default")
	scene.ghost.recording = stored
	scene.ghost.update(1,Vector3(999,999,999),true)
	check(scene.ghost.visible and scene.ghost.get_children().all(func(node: Node): return node is not CollisionObject3D),"Personal best renders during driving with no collision")
	scene.ghost.update(1,scene.ghost.position,true)
	check(not scene.ghost.visible,"Overlapping ghost fades to protect the driver's view")
	check(restored.load_ghost(RallyContentCatalog.challenge(app.chosen_stage,"F160")).is_empty(),"Another car cannot load this record")
	check(restored.load_ghost(RallyContentCatalog.challenge(app.chosen_stage,"R200",1)).is_empty(),"Another horsepower specification cannot load this record")
	scene.trajectory.frames = frames
	scene.trajectory.gaps = [[2.0,4.0]]
	scene.session.phase = RallyStageSession.Phase.FINISHED
	result.outcome = outcome
	app.show_results(result)
	check(app.screen=="results" and scene.replay.active and scene.replay.mode==0 and paused,"Result background starts TV-follow replay while physics stays paused")
	check(scene.feedback.is_paused and scene.feedback.engine_layers.values().all(func(player: AudioStreamPlayer): return not player.playing or player.stream_paused),"Replay suspends the live engine loops and wheel feedback")
	check(app.ui.find_children("*","RallyRecordConfetti",true,false).size()==1,"A saved personal record triggers its title confetti")
	check(scene.replay.actor.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,"Render-time replay cannot receive a second physics interpolation pass")
	var frozen: Transform3D = scene.vehicle.transform
	var cameras: Array[Vector3] = []
	for mode: int in range(4):
		scene.replay.set_camera(mode)
		scene.replay.seek(1)
		cameras.append(scene.camera.position)
	check(scene.replay.clear_view(scene.replay.actor.position+Vector3.UP*.7,scene.camera.position),"Replay camera keeps its sightline clear of scenery and tree crowns")
	check(cameras[0].distance_to(cameras[1])>10 and cameras[1].distance_to(cameras[2])>10 and cameras[2].distance_to(cameras[3])>5,"Four replay camera positions differ")
	scene.replay.set_camera(0)
	scene.replay.seek(.2)
	var side: float = scene.replay.broadcast_side
	for i: int in range(35): scene.replay._process(1.0/60)
	check(scene.replay.broadcast_side==side,"TV follow keeps its observation side instead of automatic cuts")
	check(scene.replay.surface_fx.marks.count>0,"Replay reconstructs tire tracks on the physical road")
	check(scene.replay.surface_fx.particles.any(func(entry: Dictionary): return entry.emitter.emitting),"Replay reconstructs wheel dust from ground contact")
	scene.replay.seek(2.5)
	check(scene.replay.surface_fx.marks.count==0 and scene.replay.surface_fx.particles.all(func(entry: Dictionary): return not entry.emitter.emitting),"Recovery/seek clears trails without a teleport streak")
	check(not scene.replay.actor.visible and scene.replay.snap,"Recovery penalty gap hides replay car without interpolating a teleport")
	scene.replay.seek(4.5)
	check(scene.replay.actor.visible,"Car reappears after recovery gap")
	scene.replay.playing = false
	var stopped: float = scene.replay.clock
	await process_frame
	await process_frame
	check(scene.replay.clock==stopped and scene.vehicle.transform==frozen,"Replay pause holds time and never advances vehicle physics")
	app._set_immersive(true)
	check(app.screen=="replay" and not app.ui.visible and app.immersive_ui.visible,"Immersive replay hides result text and keeps camera controls")
	app._set_immersive(false)
	check(app.screen=="results" and app.ui.visible,"Immersive replay returns to the existing result page")
	app.retry()
	check(app.screen=="race" and not paused and scene.replay==null and scene.vehicle.visible,"Retry removes replay and restores actual driving")
	await app.leave_race()
	await process_frame
	var album := RallyPhotoAlbum.new()
	album.directory = app.profile.path.get_base_dir()+"/gallery"
	var image := Image.create(96,54,false,Image.FORMAT_RGB8)
	image.fill(Color("d89d62"))
	check(not album.store(image,{"stage":"sunlit_cape","vehicle":"A240","power_ps":480}).is_empty(),"Aerial image and metadata save to the local album")
	var reopened := RallyPhotoAlbum.new()
	reopened.directory = album.directory
	var entries := reopened.entries()
	check(entries.size()==1 and entries[0].power_ps==480 and reopened.texture(entries[0])!=null,"Album survives re-instantiation and decodes the stored photograph")
	check(reopened.texture({"file":"../profile.json"})==null,"Album rejects paths outside its photo directory")
	app.show_gallery()
	check(app.screen=="gallery" and app.gallery_photos.size()==1,"Title gallery reads the current player's saved album")
	app.show_photo(0)
	check(app.screen=="photo","Gallery opens an individual photograph")
	app.free()
	await process_frame
	finish()

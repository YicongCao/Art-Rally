extends SceneTree
var reports: Array = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1920,1080)
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	AudioServer.set_bus_mute(0,true)
	app.profile.path = "user://performance-test/profile.json"
	app.profile.data = RallyProfileStore.fresh()
	var stages: Array = Array(RallyContentCatalog.STAGES)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="): stages = [argument.trim_prefix("--stage=")]
	for stage: String in stages:
		app.chosen_stage = stage
		app.chosen_vehicle = "A240"
		await app.start_race()
		app.race._set_autopilot_mode_name("vgamepad")
		var frames: Array[float] = []
		var physics: Array[float] = []
		var elapsed := 0.0
		var next_status := 30.0
		var previous := Time.get_ticks_usec()
		while app.race.session.phase!=RallyStageSession.Phase.FINISHED and elapsed<650:
			await process_frame
			if paused or app.race.controls.blocked:
				paused = false
				app.race.controls.resume()
			app.race.pause_menu.visible = false
			var now := Time.get_ticks_usec()
			var ms := (now-previous)/1000.0
			previous = now
			elapsed+=ms/1000
			if elapsed>=next_status:
				print("PERFORMANCE PROGRESS: ",stage," ",snappedf(app.race.session.progress,1)," m / ",snappedf(elapsed,1)," s")
				next_status+=30.0
			if elapsed>5:
				frames.append(ms)
				physics.append(app.race.vehicle.physics_usec/1000.0)
		frames.sort()
		physics.sort()
		var sum := 0.0
		for ms: float in frames: sum+=ms
		var pixels := root.get_texture().get_size()
		assert(pixels==Vector2(1920,1080),"Performance capture must actually render at 1080p")
		var report := {"stage":stage,"vehicle":"A240","resolution":[int(pixels.x),int(pixels.y)],"finished":app.race.session.phase==RallyStageSession.Phase.FINISHED,"elapsed":app.race.session.elapsed,"wall_seconds":elapsed,"frames":frames.size(),"average_fps":1000.0*frames.size()/sum,"frame_p95_ms":frames[int(frames.size()*.95)],"frame_p99_ms":frames[int(frames.size()*.99)],"physics_p95_ms":physics[int(physics.size()*.95)],"renderer":RenderingServer.get_video_adapter_name()}
		reports.append(report)
		print("FULL STAGE PERFORMANCE: ",JSON.stringify(report))
		var file := FileAccess.open("res://logs/first_playable_performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(reports,"\t"))
		await app.leave_race()
		await process_frame
	app.queue_free()
	await process_frame
	quit()

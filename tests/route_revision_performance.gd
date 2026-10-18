extends SceneTree

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1920,1080)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://lod-performance/profile.json"
	app.profile.data = RallyProfileStore.fresh()
	app.chosen_power_tier = 0
	AudioServer.set_bus_mute(0,true)
	var reports: Array = []
	var stage_filter := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage_filter = arg.trim_prefix("--stage=")
	for scenario: int in range(3):
		app.chosen_stage = ["sunset_ridge","sunlit_cape","misty_highlands"][scenario]
		if not stage_filter.is_empty() and app.chosen_stage!=stage_filter: continue
		app.chosen_vehicle = "A240"
		await app.start_race()
		var scene: Node3D = app.race
		var route: RallyStageRoute = scene.generator.route
		var station: float = [1510,2550,2900][scenario]
		var pose := route.pose_at(station)
		scene.session.projection_hint = route.index_at(station)
		scene.session.previous = pose.origin
		scene.session.progress = station
		while scene.session.gates[scene.session.next_gate]<station: scene.session.next_gate+=1
		scene.session.phase = RallyStageSession.Phase.RUNNING
		scene.vehicle.request_reset(pose)
		scene._set_autopilot_mode_name("vgamepad")
		scene.auto_driver.reset_navigation(route,pose.origin)
		scene.camera_snap = true
		var frames: Array[float] = []
		var physics: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame: int in range(240+600):
			if paused or scene.controls.blocked:
				paused = false
				scene.controls.resume()
				scene.pause_menu.visible = false
			await process_frame
			var now := Time.get_ticks_usec()
			if frame>=240:
				frames.append((now-previous)/1000.0)
				physics.append(scene.vehicle.physics_usec/1000.0)
			previous = now
		frames.sort()
		physics.sort()
		var sum := 0.0
		for ms: float in frames: sum+=ms
		var report := {"stage":app.chosen_stage,"station":station,"phase":int(scene.session.phase),"mode":"player_experience_rc3","resolution":[1920,1080],"render_frames":frames.size(),"sample_wall_seconds":sum/1000,"average_fps":1000.0*frames.size()/sum,"frame_p95_ms":frames[int(frames.size()*.95)],"frame_p99_ms":frames[int(frames.size()*.99)],"physics_p95_ms":physics[int(physics.size()*.95)],"progress":scene.session.progress,"recoveries":scene.session.reset_count,"renderer":RenderingServer.get_video_adapter_name()}
		reports.append(report)
		print("ROUTE PERFORMANCE: ",JSON.stringify(report))
		var file := FileAccess.open("res://logs/route_revision_performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(reports,"\t"))
		app.leave_race()
		await process_frame
	app.queue_free()
	await process_frame
	quit()

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
	for scenario: int in range(4):
		app.chosen_stage = ["sunset_ridge","sunset_ridge","sunlit_cape","misty_highlands"][scenario]
		app.chosen_vehicle = "A240"
		await app.start_race()
		var scene: Node3D = app.race
		var route: RallyStageRoute = scene.generator.route
		if scenario==0:
			# A/B control changes distance/fading only; content and all physics stay identical.
			for batch: MultiMeshInstance3D in scene.presentation.scenery.all_batches:
				if str(batch.name).begins_with("Aggregate"): batch.visibility_range_end = 75
				else: batch.visibility_range_end = RallySampleDressing.default_visibility(str(batch.name))/RallySampleDressing.VISIBILITY_SCALE
				batch.visibility_range_end_margin = 15
				batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				if str(batch.name).begins_with("far_"): batch.visibility_range_begin = 180
				if str(batch.name).begins_with("pine") or str(batch.name).begins_with("umbrella"): batch.visibility_range_end_margin = 0
		var station: float = [430,430,1390,1580][scenario]
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
		for frame: int in range(120+900):
			if paused or scene.controls.blocked:
				paused = false
				scene.controls.resume()
				scene.pause_menu.visible = false
			await process_frame
			var now := Time.get_ticks_usec()
			if frame>=120:
				frames.append((now-previous)/1000.0)
				physics.append(scene.vehicle.physics_usec/1000.0)
			previous = now
		frames.sort()
		physics.sort()
		var sum := 0.0
		for ms: float in frames: sum+=ms
		var report := {"stage":app.chosen_stage,"mode":"old_distance_control" if scenario==0 else "distance_plus_30_percent_with_fade","resolution":[1920,1080],"render_frames":frames.size(),"sample_wall_seconds":sum/1000,"average_fps":1000.0*frames.size()/sum,"frame_p95_ms":frames[int(frames.size()*.95)],"frame_p99_ms":frames[int(frames.size()*.99)],"physics_p95_ms":physics[int(physics.size()*.95)],"progress":scene.session.progress,"recoveries":scene.session.reset_count,"renderer":RenderingServer.get_video_adapter_name()}
		reports.append(report)
		print("LOD PERFORMANCE: ",JSON.stringify(report))
		var file := FileAccess.open("res://logs/v030_lod_performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(reports,"\t"))
		app.leave_race()
		await process_frame
	app.queue_free()
	await process_frame
	quit()

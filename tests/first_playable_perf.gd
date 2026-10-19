extends SceneTree
var reports: Array = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Fixed native render target: OS window limits / display settings must not
	# silently turn a reported 1080p benchmark into a lower-resolution run.
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1920,1080)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture=viewport.get_texture()
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	viewport.add_child(app)
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
		await RenderingServer.frame_post_draw
		if viewport.get_texture().get_size()!=Vector2(1920,1080):
			push_error("Performance target is not 1080p")
			quit(1)
			return
		if "--preflight" in OS.get_cmdline_user_args():
			viewport.get_texture().get_image().save_jpg("res://logs/performance-preflight.jpg",.9)
			print("PERFORMANCE PREFLIGHT PASSED: ",viewport.get_texture().get_size())
			await app.leave_race()
			viewport.queue_free()
			display.queue_free()
			await process_frame
			quit()
			return
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
		var pixels := viewport.get_texture().get_size()
		var report := {"stage":stage,"vehicle":"A240","resolution":[int(pixels.x),int(pixels.y)],"finished":app.race.session.phase==RallyStageSession.Phase.FINISHED,"elapsed":app.race.session.elapsed,"wall_seconds":elapsed,"frames":frames.size(),"average_fps":1000.0*frames.size()/sum,"frame_p95_ms":frames[int(frames.size()*.95)],"frame_p99_ms":frames[int(frames.size()*.99)],"physics_p95_ms":physics[int(physics.size()*.95)],"renderer":RenderingServer.get_video_adapter_name()}
		reports.append(report)
		print("FULL STAGE PERFORMANCE: ",JSON.stringify(report))
		var file := FileAccess.open("res://logs/first_playable_performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(reports,"\t"))
		await app.leave_race()
		await process_frame
	viewport.queue_free()
	display.queue_free()
	await process_frame
	quit()

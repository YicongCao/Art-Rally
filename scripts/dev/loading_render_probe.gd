extends SceneTree
# Repeatable native 1080p probe. Run with --fixed-fps 60 so camera/physics
# follow identical simulation time, independent of measured wall time.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var id := "sunset_ridge"
	var station := 600.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-stage="): id=argument.trim_prefix("--probe-stage=")
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1920,1080)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture=viewport.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://loading-probe-%d/profile.json"%OS.get_process_id()
	viewport.add_child(app)
	AudioServer.set_bus_mute(0,true)
	app.chosen_stage=id
	app.chosen_vehicle="R200"
	app.practice=true
	for repeat: int in range(2):
		var start := Time.get_ticks_usec()
		await app.start_race()
		var loaded_ms := (Time.get_ticks_usec()-start)/1000.0
		var route: RallyStageRoute=app.race.generator.route
		app.race.session.progress=station
		app.race.session.projection_hint=route.index_at(station)
		app.race.session.previous=route.position_at(station)
		app.race.session.phase=RallyStageSession.Phase.RUNNING
		while app.race.session.gates[app.race.session.next_gate]<station: app.race.session.next_gate+=1
		app.race.vehicle.request_reset(route.pose_at(station))
		app.race._set_autopilot_mode_name("vgamepad")
		app.race.auto_driver.reset_navigation(route,route.position_at(station))
		var samples: Array[float]=[]
		var draws: Array[float]=[]
		var vertices: Array[float]=[]
		var previous := Time.get_ticks_usec()
		for i: int in range(420):
			paused=false
			app.race.controls.resume()
			app.race.pause_menu.hide()
			await process_frame
			var now := Time.get_ticks_usec()
			if i>=120:
				samples.append((now-previous)/1000.0)
				draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				vertices.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			previous=now
		samples.sort()
		var sum := 0.0
		for sample: float in samples: sum+=sample
		print("LOAD_RENDER_PROBE ",JSON.stringify({"stage":id,"start_station":station,"repeat":repeat,"load_ms":loaded_ms,"fps":samples.size()*1000.0/sum,"p95_ms":samples[int(samples.size()*.95)],"p99_ms":samples[int(samples.size()*.99)],"draw_calls":draws.reduce(func(a,b): return a+b,0.0)/draws.size(),"primitives":vertices.reduce(func(a,b): return a+b,0.0)/vertices.size(),"progress":app.race.session.progress,"pixels":[1920,1080]}))
		await app.leave_race()
		await process_frame
	app.queue_free()
	await process_frame
	viewport.queue_free()
	display.queue_free()
	await process_frame
	quit()

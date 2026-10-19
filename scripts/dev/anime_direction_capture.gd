extends SceneTree
var app: RallyGameApp
var viewport: SubViewport
const DEST := "res://docs/art-direction/anime-prototype"
func _initialize() -> void: _run.call_deferred()
func frame() -> void:
	if is_instance_valid(app.race):
		if paused or app.race.controls.blocked:
			paused=false
			app.race.controls.resume()
		app.race.pause_menu.show_menu(false)
	await process_frame
func snap(label: String) -> void:
	if app.transitions.sliding and app.transitions.sliding.is_running(): await app.transitions.sliding.finished
	for i: int in range(8): await frame()
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	assert(pixels.get_size()==Vector2i(1920,1080))
	pixels.save_jpg(DEST+"/"+label+".jpg",.94)
	if label.begins_with("preview-"):
		pixels.resize(960,540,Image.INTERPOLATE_LANCZOS)
		pixels.save_jpg("res://assets/ui/screenprint_previews/"+label.trim_prefix("preview-")+".jpg",.92)
	print("ANIME CAPTURE: ",label)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	viewport=SubViewport.new()
	viewport.size=Vector2i(1920,1080)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.texture=viewport.get_texture()
	root.add_child(display)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://anime-direction-review/profile.json"
	viewport.add_child(app)
	AudioServer.set_bus_mute(0,true)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="ART-RALLY"
	app.show_home()
	await snap("title")
	app.show_vehicles()
	await snap("vehicles")
	var report := {}
	for index: int in range(3):
		app.chosen_stage=RallyContentCatalog.STAGES[index]
		app.chosen_vehicle=RallyContentCatalog.VEHICLES[index]
		await app.start_race()
		var route: RallyStageRoute=app.race.generator.route
		var station: float=[430,1390,1580][index]
		var pose := route.pose_at(station)
		app.race.session.projection_hint=route.index_at(station)
		app.race.session.previous=pose.origin
		app.race.session.progress=station
		while app.race.session.gates[app.race.session.next_gate]<station:app.race.session.next_gate+=1
		app.race.session.phase=RallyStageSession.Phase.RUNNING
		app.race.vehicle.request_reset(pose)
		app.race._set_autopilot_mode_name("vgamepad")
		app.race.auto_driver.reset_navigation(route,pose.origin)
		app.race.camera_snap=true
		for i: int in range(120):await frame()
		await snap(app.chosen_stage)
		app.race.game_hud.modulate.a=0
		await snap("preview-"+app.chosen_stage)
		app.race.game_hud.modulate.a=1
		var times: Array[float]=[]
		for i: int in range(360):
			var start := Time.get_ticks_usec()
			await frame()
			times.append((Time.get_ticks_usec()-start)/1000.0)
		times.sort()
		report[app.chosen_stage]={"actual_pixels":"1920x1080","sample_frames":times.size(),"p95_wall_ms":times[int(times.size()*.95)],"p99_wall_ms":times[int(times.size()*.99)],"progress_m":app.race.session.progress-station,"note":"Short native capture sample; includes capture viewport presentation; not a full-stage benchmark."}
		if app.race.session.progress<station+15:
			push_error("Vehicle did not advance")
			quit(1)
			return
		if index==0:
			var camera := Camera3D.new()
			app.race.add_child(camera)
			camera.fov=65
			camera.far=6200
			camera.global_position=route.position_at(470)+Vector3.UP*3
			camera.look_at(route.position_at(550)+Vector3.UP*12)
			camera.make_current()
			app.race.game_hud.modulate.a=0
			await snap("landscape")
			app.race.camera.make_current()
			camera.queue_free()
		await app.leave_race()
	FileAccess.open(DEST+"/capture-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ANIME CAPTURE PASSED")
	viewport.queue_free()
	await process_frame
	quit()

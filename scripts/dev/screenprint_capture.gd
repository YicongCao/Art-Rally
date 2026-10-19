extends SceneTree
var app: RallyGameApp
var destination: String
var metrics: Dictionary = {}
func _initialize() -> void: _run.call_deferred()
func capture(label: String) -> void:
	if app.transitions.sliding and app.transitions.sliding.is_running(): await app.transitions.sliding.finished
	for i: int in range(8):
		resume_capture()
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_jpg(destination+"/"+label+".jpg",.92)
	if label.begins_with("preview-") and not "--baseline" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://assets/ui/screenprint_previews")
		image.resize(960,540,Image.INTERPOLATE_LANCZOS)
		image.save_jpg("res://assets/ui/screenprint_previews/"+label.trim_prefix("preview-")+".jpg",.92)
	print("CAPTURE: ",label)
func resume_capture() -> void:
	if is_instance_valid(app.race):
		if paused or app.race.controls.blocked:
			paused = false
			app.race.controls.resume()
		app.race.pause_menu.show_menu(false)
func _run() -> void:
	root.size = Vector2i(1920,1080)
	destination = "res://docs/art-direction/screenprint/"+("baseline" if "--baseline" in OS.get_cmdline_user_args() else "current")
	DirAccess.make_dir_recursive_absolute(destination)
	app = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	AudioServer.set_bus_mute(0,true)
	await capture("home")
	app.show_stages()
	await capture("stages")
	app.show_vehicles()
	await capture("vehicles")
	for i: int in range(3):
		app.chosen_stage = RallyContentCatalog.STAGES[i]
		app.chosen_vehicle = RallyContentCatalog.VEHICLES[i]
		await app.start_race()
		paused = false
		app.race.controls.resume()
		app.race._set_autopilot_mode_name("vgamepad")
		var station: float = [430,1390,1580][i]
		var route: RallyStageRoute = app.race.generator.route
		var pose := route.pose_at(station)
		app.race.session.projection_hint = route.index_at(station)
		app.race.session.previous = pose.origin
		app.race.session.progress = station
		while app.race.session.gates[app.race.session.next_gate] < station:
			app.race.session.next_gate += 1
		app.race.session.phase = RallyStageSession.Phase.RUNNING
		app.race.vehicle.request_reset(pose)
		app.race.auto_driver.reset_navigation(route,pose.origin)
		app.race.camera_snap = true
		for tick: int in range(90):
			resume_capture()
			await physics_frame
		await capture(RallyContentCatalog.STAGES[i])
		app.race.game_hud.modulate.a=0
		await capture("preview-"+RallyContentCatalog.STAGES[i])
		app.race.game_hud.modulate.a=1
		var samples: Array[float] = []
		for frame: int in range(180):
			resume_capture()
			await process_frame
			samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		samples.sort()
		var total: float = 0
		for value: float in samples: total+=value
		metrics[RallyContentCatalog.STAGES[i]] = {"mean_cpu_frame_ms":total/samples.size(),"p95_cpu_frame_ms":samples[int(samples.size()*.95)],"p99_cpu_frame_ms":samples[int(samples.size()*.99)],"frames":samples.size(),"resolution":"1920x1080","note":"Short moving capture sample; CPU process time, not full-stage GPU or wall-frame benchmark"}
		app.race.presentation.environment.adjustment_enabled = true
		app.race.presentation.environment.adjustment_saturation = 0
		await capture(RallyContentCatalog.VEHICLES[i]+"-gray")
		app.race.presentation.environment.adjustment_enabled = false
		app.race.camera_mode = 2
		await capture(RallyContentCatalog.VEHICLES[i]+"-cockpit")
		if i > 0: await capture_environment_detail(i)
		await app.leave_race()
		await process_frame
	FileAccess.open(destination+"/capture-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	app.queue_free()
	await process_frame
	quit()


func capture_environment_detail(index: int) -> void:
	var camera := Camera3D.new()
	app.race.add_child(camera)
	camera.current = true
	app.race.game_hud.visible = false
	app.race.presentation.flare.enabled = false
	if index == 1:
		var scenery: RallyStageScenery = app.race.presentation.scenery
		camera.global_position = Vector3(scenery.bounds.position.x-650,-12,scenery.center.z)
		var direction: Vector3 = app.race.presentation.atmosphere.sun_direction
		camera.look_at(camera.global_position+Vector3(direction.x,-.22,direction.z).normalized()*120)
		await capture("ocean-glints")
	else:
		var route: RallyStageRoute = app.race.generator.route
		camera.global_position = route.position_at(380)+route.rights[route.index_at(380)]*15+Vector3.UP*7
		camera.look_at(route.position_at(700)+Vector3.UP*2)
		await capture("morning-mist")
	app.race.camera.make_current()
	camera.queue_free()
	app.race.game_hud.visible = true
	app.race.presentation.flare.enabled = true

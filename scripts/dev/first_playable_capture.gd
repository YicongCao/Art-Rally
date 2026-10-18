extends SceneTree
var app: RallyGameApp
func _initialize() -> void: _run.call_deferred()
func capture(label: String) -> void:
	for i: int in range(8):
		resume_capture()
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_jpg("res://docs/previews/first-playable-"+label+".jpg",.9)
	print("CAPTURE: ",label)
func resume_capture() -> void:
	if is_instance_valid(app.race) and (paused or app.race.controls.blocked):
		paused = false
		app.race.controls.resume()
		app.race.pause_menu.show_menu(false)
func _run() -> void:
	root.size = Vector2i(1280,720)
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
		app.race.presentation.environment.adjustment_enabled = true
		app.race.presentation.environment.adjustment_saturation = 0
		await capture(RallyContentCatalog.VEHICLES[i]+"-gray")
		app.race.presentation.environment.adjustment_enabled = false
		app.race.camera_mode = 2
		await capture(RallyContentCatalog.VEHICLES[i]+"-cockpit")
		app.leave_race()
		await process_frame
	app.queue_free()
	await process_frame
	quit()

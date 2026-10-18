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
		if i > 0: await capture_environment_detail(i)
		await app.leave_race()
		await process_frame
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

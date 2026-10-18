extends SceneTree
var app: RallyGameApp

func _initialize() -> void: _run.call_deferred()
func capture(label: String,frames: int = 6) -> void:
	for i: int in range(frames): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/v030-"+label+".jpg",.93)
	print("CAPTURE: ",label)
func _run() -> void:
	root.size = Vector2i(1280,720)
	app = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://v030-capture/profile.json"
	app.profile.data = RallyProfileStore.fresh()
	app.profile.data.plate = "山野-030"
	AudioServer.set_bus_mute(0,true)
	app.show_home()
	await capture("home")
	app.show_vehicles()
	await capture("locked")
	# Isolated screenshot fixture; no medal or player save is fabricated.
	app.profile.data.unlocked_power_tier = 2
	app.chosen_power_tier = 2
	app.show_vehicles()
	await capture("power")
	app.start_race()
	await capture("loading",2)
	while app.loading: await process_frame
	app.race._set_autopilot_mode_name("vgamepad")
	var station := 310.0
	var route: RallyStageRoute = app.race.generator.route
	var pose := route.pose_at(station)
	app.race.session.projection_hint = route.index_at(station)
	app.race.session.previous = pose.origin
	app.race.session.progress = station
	while app.race.session.gates[app.race.session.next_gate] < station: app.race.session.next_gate+=1
	app.race.session.phase = RallyStageSession.Phase.RUNNING
	app.race.vehicle.request_reset(pose)
	app.race.auto_driver.reset_navigation(route,pose.origin)
	app.race.camera_snap = true
	for i: int in range(40):
		if paused or app.race.controls.blocked:
			paused = false
			app.race.controls.resume()
		await physics_frame
	await capture("crowds")
	await app.leave_race()
	app.queue_free()
	await process_frame
	quit()

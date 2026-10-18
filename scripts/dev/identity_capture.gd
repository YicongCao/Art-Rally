extends SceneTree

var app: RallyGameApp


func _initialize() -> void:
	_run.call_deferred()


func capture(label: String) -> void:
	for i: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/identity-" + label + ".jpg",.93)
	print("CAPTURE: ",label)


func _run() -> void:
	root.size = Vector2i(1280,720)
	app = load("res://scenes/game/game.tscn").instantiate()
	var directory := "user://identity-capture-" + str(Time.get_ticks_usec())
	app.profile.path = directory + "/profile.json"
	root.add_child(app)
	AudioServer.set_bus_mute(0,true)
	app.plate_input.text = "沪A·RALLY"
	app.plate_input.text_changed.emit(app.plate_input.text)
	await capture("setup")
	app._submit_plate(true)
	app.chosen_stage = "sunlit_cape"
	app.chosen_vehicle = "R200"
	app.show_briefing()
	await capture("briefing")
	app.show_settings()
	await capture("settings")
	for id: String in RallyContentCatalog.VEHICLES:
		app.chosen_stage = "sunset_ridge"
		app.chosen_vehicle = id
		await app.start_race()
		for i: int in range(75):
			if paused or app.race.controls.blocked:
				paused = false
				app.race.controls.resume()
				app.race.pause_menu.show_menu(false)
			await physics_frame
		if id == "F160":
			await capture("driving")
			app.race._toggle_pause()
			await capture("pause")
			app.race._toggle_pause()
		paused = true
		app.race.set_process(false)
		app.race.game_hud.visible = false
		app.race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		app.race.camera.size = 2.3
		app.race.camera.global_position = app.race.vehicle.to_global(Vector3(.9,1.0,app.race.challenge.vehicle.body_size.z/2+2.5))
		app.race.camera.look_at(app.race.vehicle.to_global(Vector3(0,.13,app.race.challenge.vehicle.body_size.z/2)))
		await capture(id + "-rear")
		if id == "F160":
			app.race.camera.global_position = app.race.vehicle.to_global(Vector3(-.9,1.0,-app.race.challenge.vehicle.body_size.z/2-2.5))
			app.race.camera.look_at(app.race.vehicle.to_global(Vector3(0,.13,-app.race.challenge.vehicle.body_size.z/2)))
			await capture("F160-front")
		app.leave_race()
		await process_frame
	app.queue_free()
	await process_frame
	var access := DirAccess.open(directory)
	for file: String in access.get_files(): access.remove(file)
	DirAccess.remove_absolute(directory)
	quit()

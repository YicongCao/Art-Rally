extends SceneTree
var app: RallyGameApp
func _initialize() -> void: _run.call_deferred()
func capture(label: String) -> void:
	for i: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_jpg("res://docs/previews/first-playable-"+label+".jpg",.9)
	print("CAPTURE: ",label)
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
		app.race.vehicle.request_reset(app.race.generator.route.pose_at([470,1450,1650][i]))
		for tick: int in range(90): await physics_frame
		await capture(RallyContentCatalog.STAGES[i])
		app.leave_race()
		await process_frame
	app.queue_free()
	await process_frame
	quit()

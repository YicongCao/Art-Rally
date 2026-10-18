extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1280,720)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://dust-capture/profile.json"
	app.profile.data=RallyProfileStore.fresh()
	app.chosen_stage="sunset_ridge"
	app.chosen_vehicle="A240"
	AudioServer.set_bus_mute(0,true)
	await app.start_race()
	app.race._set_autopilot_mode_name("vgamepad")
	for i: int in range(1400):
		if paused or app.race.controls.blocked:
			paused=false
			app.race.controls.resume()
			app.race.pause_menu.show_menu(false)
		await physics_frame
	app.race.pause_menu.show_menu(false)
	for entry: Dictionary in app.race.feedback.particles:
		if entry.kind=="dust": print("DUST ",entry.emitter.emitting," ratio ",entry.emitter.amount_ratio," pos ",entry.emitter.global_position," bounds ",entry.emitter.capture_aabb()," wheel ",app.race.vehicle.wheels[entry.wheel].grounded)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/route-v2-dust.jpg",.95)
	# Park the camera to observe the trail from the verge as well.
	app.race.set_process(false)
	var pose: Transform3D=app.race.vehicle.global_transform
	app.race.camera.position=pose*Vector3(5,3,9)
	app.race.camera.look_at(pose*Vector3(0,0,3))
	for i: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/route-v2-dust-side.jpg",.95)
	await app.leave_race()
	app.queue_free()
	await process_frame
	quit()

extends SceneTree

# Six current-version README frames. Isolated profile; real autopilot physics,
# followed by the standard results replay of that captured trajectory.
var app: RallyGameApp
func _initialize() -> void: _run.call_deferred()
func resume_drive() -> void:
	if paused or app.race.controls.blocked:
		paused = false
		app.race.controls.resume()
		app.race.pause_menu.hide()
func shot(label: String) -> void:
	await create_timer(.65).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size()==Vector2i(1280,720))
	assert(image.save_jpg("res://docs/previews/showcase-"+label+".jpg",.92)==OK)
	print("README SHOT: ",label)
func _run() -> void:
	assert(DisplayServer.get_name()!="headless")
	assert("--test-defaults" in OS.get_cmdline_user_args())
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://readme-showcase-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="ART RALLY"
	AudioServer.set_bus_mute(0,true)
	app.show_home()
	await shot("home")
	if "--home-only" in OS.get_cmdline_user_args():
		app.free()
		await process_frame
		quit()
		return
	app.show_stages()
	await shot("stages")
	for index: int in range(3):
		app.chosen_stage=RallyContentCatalog.STAGES[index]
		app.chosen_vehicle=RallyContentCatalog.VEHICLES[index]
		await app.start_race()
		resume_drive()
		var race: Node3D=app.race
		var route: RallyStageRoute=race.generator.route
		var station: float=[430,route.length-115,1580][index]
		var pose:=route.pose_at(station)
		race.session.projection_hint=route.index_at(station)
		race.session.previous=pose.origin
		race.session.progress=station
		while race.session.gates[race.session.next_gate]<station: race.session.next_gate+=1
		race.session.phase=RallyStageSession.Phase.RUNNING
		race.vehicle.request_reset(pose)
		race._set_autopilot_mode_name("vgamepad")
		race.auto_driver.reset_navigation(route,pose.origin)
		race.camera_snap=true
		for tick: int in range(480):
			resume_drive()
			await physics_frame
		assert(race.vehicle.linear_velocity.length()>2)
		await shot(app.chosen_stage)
		if index==0:
			race.trajectory.capture(race.session.total_time(),race.vehicle,true)
			var elapsed: float=race.session.total_time()
			race.session.phase=RallyStageSession.Phase.FINISHED
			app.show_results({"elapsed":elapsed,"penalty":0,"total_time":elapsed,"splits":[],"outcome":{"eligible":false,"new_best":false}})
			assert(race.replay.active)
			race.replay.seek(elapsed-1.5)
			race.replay.playing=false
			await shot("replay")
		await app.leave_race()
	app.free()
	await process_frame
	print("README SHOWCASE PASSED: six frames")
	quit()

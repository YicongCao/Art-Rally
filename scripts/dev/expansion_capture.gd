extends SceneTree

var app: RallyGameApp

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app = load("res://scenes/game/game.tscn").instantiate()
	app.profile.path = "user://expansion-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data = RallyProfileStore.fresh()
	app.profile.data.plate = "沪A·RALLY"
	app.profile.data.unlocked_power_tier = 2
	AudioServer.set_bus_mute(0,true)
	app.show_home()
	await shot("home")
	app.chosen_vehicle = "R200"
	app.chosen_power_tier = 1
	app.show_vehicles()
	await shot("vehicles")
	app.show_plate_setup()
	await shot("plate")
	app.show_stages()
	await shot("stages")
	app.show_guide()
	await shot("guide")
	if "--ui-only" in OS.get_cmdline_user_args():
		app.queue_free()
		await process_frame
		quit()
		return
	for stage: String in RallyContentCatalog.STAGES:
		app.chosen_stage = stage
		app.chosen_vehicle = "A240"
		app.chosen_power_tier = 0
		await app.start_race()
		var scene: Node3D = app.race
		var river: Vector3 = scene.challenge.stage.river_crossings[0]
		await place(scene,river.x-25)
		paused = true
		scene.set_process(false)
		scene.game_hud.visible = false
		var route: RallyStageRoute = scene.generator.route
		var at := route.position_at(river.x)
		var right := route.rights[route.index_at(river.x)]
		var forward := route.tangent_at(river.x)
		scene.presentation.camera_rig.dashboard.visible = false
		scene.camera.position = at+right*24-forward*24+Vector3.UP*18
		scene.camera.look_at(at-Vector3.UP*1.0)
		await shot(stage+"-bridge")
		var balloon: Node3D = scene.presentation.sky_life.balloons[3].node
		var station := route.length*.69
		scene.camera.position = route.position_at(station)+Vector3.UP*12
		scene.camera.look_at(balloon.global_position-Vector3.UP*50)
		await shot(stage+"-balloons")
		await place(scene,route.length*.53)
		scene.set_process(false)
		paused = true
		scene.game_hud.visible = false
		scene.broadcast.photos_enabled = true
		scene.broadcast.reset()
		scene.session.phase = RallyStageSession.Phase.RUNNING
		scene.session.progress = route.length*.53
		scene.broadcast.advance(5)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		print("CAPTURED PHOTO ",stage,": ",scene.broadcast.last_saved)
		scene.camera.position = scene.vehicle.position+route.rights[route.index_at(route.length*.53)]*42+Vector3.UP*20+route.tangent_at(route.length*.53)*10
		scene.camera.look_at(scene.broadcast.airframe.global_position.lerp(scene.vehicle.position,.45))
		await shot(stage+"-helicopter")
		if stage=="sunlit_cape":
			at = route.position_at(route.length-55)
			right = route.rights[-10]
			scene.camera.position = at+right*12+Vector3.UP*14
			scene.camera.look_at(scene.presentation.scenery.sailboats[0].node.global_position+Vector3.UP*6)
			await shot("sailing-bay")
		await app.leave_race()
		await process_frame
	app.show_gallery()
	await shot("gallery")
	if not app.gallery_photos.is_empty():
		app.show_photo(0)
		await shot("photo")
	app.queue_free()
	await process_frame
	quit()

func place(scene: Node3D,station: float) -> void:
	paused = false
	scene.controls.resume()
	scene.pause_menu.visible = false
	var route: RallyStageRoute = scene.generator.route
	scene.session.phase = RallyStageSession.Phase.RUNNING
	scene.session.progress = station
	scene.session.projection_hint = route.index_at(station)
	scene.session.previous = route.position_at(station)
	while scene.session.next_gate<scene.session.gates.size()-1 and scene.session.gates[scene.session.next_gate]<station: scene.session.next_gate+=1
	scene.vehicle.request_reset(route.pose_at(station))
	for i: int in range(5): await physics_frame
	scene.camera_snap = true

func shot(label: String) -> void:
	for i: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/polish-"+label+".jpg",.9)
	print("SAVED ",label)

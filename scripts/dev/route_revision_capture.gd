extends SceneTree
var app: RallyGameApp
func _initialize() -> void: _run.call_deferred()
func capture(label: String) -> void:
	for i: int in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/route-v2-"+label+".jpg",.94)
	print("CAPTURE ",label)
func place(s: float) -> void:
	var scene: Node3D = app.race
	var route: RallyStageRoute = scene.generator.route
	var pose := route.pose_at(s)
	scene.session.projection_hint = route.index_at(s)
	scene.session.previous = pose.origin
	scene.session.progress = s
	scene.session.next_gate = 1
	while scene.session.gates[scene.session.next_gate]<s: scene.session.next_gate+=1
	scene.session.phase = RallyStageSession.Phase.RUNNING
	scene.vehicle.request_reset(pose)
	scene.auto_driver.reset_navigation(route,pose.origin)
	scene.presentation.camera_rig.reset()
	for i: int in range(45):
		if paused or scene.controls.blocked:
			paused = false
			scene.controls.resume()
		await physics_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	app = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://route-v2-capture/profile.json"
	app.profile.data = RallyProfileStore.fresh()
	app.profile.data.plate = "山野-030"
	app.profile.data.unlocked_power_tier = 2
	AudioServer.set_bus_mute(0,true)
	app.chosen_vehicle = "R200"
	app.chosen_power_tier = 1
	app.show_vehicles()
	await capture("vehicles")
	for id: String in ["misty_highlands","sunset_ridge","sunlit_cape"]:
		app.chosen_stage = id
		app.chosen_vehicle = "A240"
		app.chosen_power_tier = 0
		await app.start_race()
		app.race._set_autopilot_mode_name("vgamepad")
		if id=="misty_highlands":
			await place(8)
			await capture("highland-start")
			await place(220)
			await capture("highland-220")
			await place(app.race.generator.route.length-60)
			await capture("summit-drive")
		elif id=="sunset_ridge":
			await place(app.race.generator.route.length*.53-45)
			await capture("arch")
			await place(280)
			for i: int in range(300):
				if paused or app.race.controls.blocked:
					paused = false
					app.race.controls.resume()
				await physics_frame
			await capture("dust")
		else:
			await place(app.race.generator.route.length-85)
			await capture("coast-drive")
		# An elevated photo of the landmark supplements, rather than replaces, actual driving views.
		app.race.set_process(false)
		app.race.set_physics_process(false)
		app.race.vehicle.freeze = true
		app.race.game_hud.visible = false
		var land: RallyStageScenery = app.race.presentation.scenery
		if id=="sunlit_cape":
			var deck: Node3D = land.dressing.get_node("GoldenCoastOverlook")
			app.race.camera.position = deck.to_global(Vector3(38,25,24))
			app.race.camera.look_at(deck.to_global(Vector3(-42,-8,-5)))
		elif id=="misty_highlands":
			var deck: Node3D = land.dressing.get_node("SummitBelvedere")
			app.race.camera.position = deck.to_global(Vector3(22,12,20))
			app.race.camera.look_at(deck.to_global(Vector3(-30,-12,-30)))
		else:
			var service: Node3D = land.dressing.get_node("MedicalAndMarshals")
			app.race.camera.position = service.to_global(Vector3(-13,8,16))
			app.race.camera.look_at(service.global_position+Vector3.UP)
		await capture(id+"-landmark")
		if id=="sunlit_cape":
			var beach: Node3D = land.dressing.get_node("GoldenBeach")
			app.race.camera.position = beach.to_global(Vector3(-12,8,-2))
			app.race.camera.look_at(beach.to_global(Vector3(2,0,-16)))
			await capture("beach-detail")
		app.leave_race()
		await process_frame
	app.queue_free()
	await process_frame
	quit()

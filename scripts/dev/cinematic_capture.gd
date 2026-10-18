extends SceneTree

var app: RallyGameApp
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	app = load("res://scenes/game/game.tscn").instantiate()
	app.profile.path = "user://cinematic-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data = RallyProfileStore.fresh()
	app.profile.data.plate = "ART-RALLY"
	app.chosen_vehicle = "R200"
	app.profile.data.unlocked_power_tier = 2
	AudioServer.set_bus_mute(0,true)
	app.show_home()
	await create_timer(.3).timeout
	await shot("title")
	if "--ui-only" in OS.get_cmdline_user_args():
		app.queue_free()
		await process_frame
		quit()
		return
	app.show_stages()
	await create_timer(.06).timeout
	await shot("slide")
	await create_timer(.25).timeout
	app.show_vehicles()
	await create_timer(.25).timeout
	app.chosen_stage = "sunlit_cape"
	await app.start_race()
	print("FLAG TRANSITION COMPLETED; screen=",app.screen," busy=",app.transitions.busy)
	app.transitions.wipe.black = false
	app.transitions.wipe.phase = .5
	app.transitions.wipe.show()
	await shot("flag")
	app.transitions.wipe.phase = 1
	await shot("flag-covered")
	app.transitions.wipe.hide()
	var scene: Node3D = app.race
	scene.controls.suspend()
	paused = true
	scene.set_process(false)
	scene.game_hud.visible = false
	var route: RallyStageRoute = scene.generator.route
	var station: float = scene.challenge.stage.river_crossings[0].x
	scene.vehicle.request_reset(route.pose_at(station,.65))
	paused = false
	for i: int in range(120): await physics_frame
	paused = true
	var at := route.position_at(station)
	var right := route.rights[route.index_at(station)]
	var forward := route.tangent_at(station)
	scene.camera.position = at+right*10-forward*13+Vector3.UP*6
	scene.camera.look_at(at+Vector3.UP*.45)
	await shot("bridge")
	var lighthouse: Node3D = scene.presentation.scenery.dressing.get_node("Lighthouse")
	var beacon: RallyLighthouseBeacon = lighthouse.find_children("*","RallyLighthouseBeacon",true,false)[0]
	beacon.rotation.y = 1.3
	scene.camera.position = lighthouse.position+Vector3(60,30,80)
	scene.camera.look_at(lighthouse.position+Vector3(0,15,0))
	await shot("lighthouse")
	await app.leave_race()
	print("BLACK RETURN COMPLETED; screen=",app.screen," busy=",app.transitions.busy)
	await shot("return")
	app.queue_free()
	await process_frame
	quit()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/cinematic-"+label+".jpg",.92)
	print("SAVED ",label)

extends SceneTree

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://utility-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="BRUSHLINE"
	AudioServer.set_bus_mute(0,true)
	for stage_id: String in RallyContentCatalog.STAGES:
		if not OS.get_cmdline_user_args().is_empty() and stage_id!=OS.get_cmdline_user_args()[0]: continue
		app.chosen_stage=stage_id
		await app.start_race()
		var scene: Node3D=app.race
		paused=true
		scene.set_process(false)
		scene.game_hud.hide()
		var land: RallyStageScenery=scene.presentation.scenery
		var station := 230.0
		scene.camera.position=land.ground_at(station-30,0)+Vector3.UP*6
		scene.camera.look_at(land.ground_at(station+80,17)+Vector3.UP*5)
		await process_frame
		scene.pause_menu.hide()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("res://docs/previews/utility-"+stage_id+".jpg",.94)
		print("SAVED ",stage_id)
		await app.leave_race()
	var start := Time.get_ticks_msec()
	await app.transitions.cover(true)
	var covered := Time.get_ticks_msec()
	await app.transitions.reveal(true)
	print("FLAG TIMING enter_ms=",covered-start," hold_and_exit_ms=",Time.get_ticks_msec()-covered)
	app.free()
	await process_frame
	quit()

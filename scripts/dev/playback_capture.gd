extends SceneTree

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	app.profile.path = "user://playback-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data = RallyProfileStore.fresh()
	app.profile.data.plate = "ART-RALLY"
	app.chosen_vehicle = "A240"
	AudioServer.set_bus_mute(0,true)
	await app.start_race()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://logs/route-replay-sunset_ridge.json"))
	var trajectory: Dictionary = saved.recording
	var report: Dictionary = saved.result
	app.race.trajectory.frames = trajectory.frames
	app.race.trajectory.gaps = trajectory.gaps
	app.race.session.phase = RallyStageSession.Phase.FINISHED
	app.show_results({"elapsed":report.elapsed,"penalty":0,"total_time":report.elapsed,"splits":report.splits,"outcome":{"eligible":false,"new_best":false}})
	app.race.replay.seek(128)
	app.race.replay.playing = false
	await shot("results")
	app._set_immersive(true)
	app.immersive_idle = 5
	Input.warp_mouse(Vector2(40,40))
	for mode: int in range(4):
		app.race.replay.set_camera(mode)
		app.race.replay.seek(128)
		await shot("replay-%d"%mode)
	app._set_immersive(false)
	app.leave_race()
	app.show_guide()
	await shot("guide")
	app.queue_free()
	await process_frame
	quit()

func shot(label: String) -> void:
	for i: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/polish-"+label+".jpg",.9)
	print("SAVED ",label)

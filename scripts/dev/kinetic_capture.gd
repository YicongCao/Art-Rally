extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	app.profile.path = "user://kinetic-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data = RallyProfileStore.fresh()
	app.chosen_vehicle = "A240"
	AudioServer.set_bus_mute(0,true)
	await app.start_race()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://logs/route-replay-sunset_ridge.json"))
	app.race.trajectory.frames = saved.recording.frames
	app.race.trajectory.unwrapped_spins = saved.recording.get("unwrapped_spins",false)
	app.race.trajectory.gaps = saved.recording.gaps
	app.race.session.phase = RallyStageSession.Phase.FINISHED
	app.show_results({"elapsed":saved.result.elapsed,"penalty":0,"total_time":saved.result.elapsed,"splits":saved.result.splits,"outcome":{"eligible":false}})
	app._set_immersive(true)
	Input.warp_mouse(Vector2(40,40))
	var capture_motion := "--capture-motion" in OS.get_cmdline_user_args()
	var frame_number := 0
	if capture_motion: DirAccess.make_dir_recursive_absolute("res://logs/replay-motion")
	for mode: int in [2,0]:
		app.race.replay.set_camera(mode)
		app.race.replay.seek(233)
		app.immersive_idle = 5
		for i: int in range(110):
			await process_frame
			if capture_motion and i%2==0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg("res://logs/replay-motion/%04d.jpg"%frame_number,.86)
				frame_number+=1
		app.immersive_idle = 5
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("res://docs/previews/polish-speed-trails"+("-side" if mode==0 else "")+".jpg",.9)
		print("TRAIL AABB ",app.race.replay.streaks.mesh.get_aabb())
	await app.leave_race()
	app.queue_free()
	for i: int in range(3): await process_frame
	quit()

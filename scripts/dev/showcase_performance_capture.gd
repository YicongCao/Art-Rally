extends SceneTree
# Actual native playback, without --fixed-fps or MovieWriter. Independent player profile.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://showcase-performance/profile.json"
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	await app.start_benchmark()
	var demo := app.showcase
	if not is_instance_valid(demo): quit(1); return
	await demo.finished
	var report := demo.performance.report()
	if report.is_empty(): printerr("No native performance samples"); quit(1); return
	var output := report.duplicate(true)
	output.curve=[]
	for point: Vector2 in report.curve: output.curve.append([point.x,point.y])
	output.resolution="1280x720"
	output.renderer=RenderingServer.get_current_rendering_method()
	output.gpu=RenderingServer.get_video_adapter_name()
	output.note="Native playback wall-clock cadence; no MovieWriter; loading and pause excluded; single-frame extrema. Device-specific, not a performance guarantee."
	FileAccess.open("res://docs/brushline/showcase/validation/playback-performance.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		DisplayServer.window_set_size(resolution)
		for frame: int in range(30): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("res://docs/brushline/showcase/validation/performance-%d.jpg"%resolution.x,.93)
	print("NATIVE_PLAYBACK_RESULT ",report.frames," frames; ",report.average," average FPS")
	app._showcase_replay()
	if not demo.performance.report().is_empty(): printerr("Replay retained previous stats"); quit(1); return
	app._showcase_exit()
	for frame: int in range(2): await process_frame
	app.free()
	await process_frame
	quit()

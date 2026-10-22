extends SceneTree
# Play the full 75 s showcase in a real window and report wall-clock frame rate.
#   godot --path . --script res://scripts/dev/showcase_perf_probe.gd -- --test-defaults --size=2560x1440
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var size := Vector2i(2560,1440)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			size=Vector2i(int(parts[0]),int(parts[1]))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=size
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://showcase-perf-%d/profile.json"%OS.get_process_id()
	root.add_child(app)
	AudioServer.set_bus_mute(0,true)
	await app.start_benchmark()
	var demo: RallyShowcaseDirector=app.showcase
	demo.performance.enabled=true
	demo.restart()
	# Stop on the film clock, not the finished signal: the app frees nothing here.
	var start := Time.get_ticks_msec()
	while demo.clock<RallyShowcaseDirector.DURATION-.05 and Time.get_ticks_msec()-start<180000: await process_frame
	var report: Dictionary=demo.performance.report()
	var times: Array=[]
	for frame: Vector2 in demo.performance.frames: times.append(frame.y*1000)
	times.sort()
	var world: RallyShowcaseWorld=demo.worlds.values()[0]
	print("SHOWCASE_PERF ",JSON.stringify({"window":[root.size.x,root.size.y],"render":[world.viewport.size.x,world.viewport.size.y],"frames":report.frames,"average_fps":snappedf(report.average,.1),"p95_ms":snappedf(times[int(times.size()*.95)],.01),"p99_ms":snappedf(times[int(times.size()*.99)],.01),"renderer":RenderingServer.get_video_adapter_name()}))
	quit()

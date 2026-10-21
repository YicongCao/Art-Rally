extends SceneTree

# Godot MovieWriter captures these real-time-rendered replay poses at normal speed.
# --write-movie logs/showcase/native.avi --fixed-fps 60
# -- --from=11 --duration=17 --fps=60 --test-defaults
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var options := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.trim_prefix("--").split("=",true,1)
			options[pair[0]]=pair[1]
	var fps := int(options.get("fps",60))
	var start := float(options.get("from",0))
	var duration := float(options.get("duration",75))
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://showcase-movie/profile.json"
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	await app.start_benchmark()
	var demo := app.showcase
	if not is_instance_valid(demo): quit(1); return
	demo.set_process(false)
	demo.playing=true
	demo.soundtrack.start()
	var first_frame := -1
	for i: int in range(roundi(duration*fps)):
		await process_frame
		demo.clock=start+float(i)/fps
		demo._render(1.0/fps)
		if i==0:
			first_frame=Engine.get_frames_drawn()
			print("MOVIE_FIRST_FRAME ",first_frame)
		if i%fps==0: print("MOVIE_SECOND ",demo.clock)
		await RenderingServer.frame_post_draw
	var meta := {"first_frame":first_frame,"frames":roundi(duration*fps),"fps":fps,"start":start,"duration":duration,"last_drawn":Engine.get_frames_drawn()}
	FileAccess.open("res://logs/showcase/movie-%d-%d.json"%[start,fps],FileAccess.WRITE).store_string(JSON.stringify(meta))
	print("MOVIE_COMPLETE ",JSON.stringify(meta))
	app.free()
	await process_frame
	quit()

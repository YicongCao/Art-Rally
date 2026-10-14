extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://scenes/dev/visual_sample.tscn").instantiate()
	root.add_child(scene)
	var station := 445.0
	var angle := false
	var gray := "--gray" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--at="): station = float(argument.trim_prefix("--at="))
		if argument == "--angle": angle = true
	scene.jump_to(station)
	scene.show_hud = "--hud" in OS.get_cmdline_user_args()
	scene.set_style(not gray)
	scene.sun_view = "--sun" in OS.get_cmdline_user_args()
	scene.flare.enabled = not "--no-flare" in OS.get_cmdline_user_args()
	for i: int in range(180):
		paused = false
		await physics_frame
	if "--moving" in OS.get_cmdline_user_args():
		scene.vehicle.command_source = func(_speed: float,_dt: float) -> DriverCommand:
			var command := DriverCommand.new()
			command.throttle = 0.8
			return command
		for i: int in range(300):
			paused = false
			await physics_frame
	if angle:
		scene.set_process(false)
		var pose: Transform3D = scene.vehicle.global_transform
		scene.camera.position = pose * Vector3(5.4,3.0,7.2)
		scene.camera.look_at(pose.origin + Vector3.UP*0.4 - pose.basis.z*8)
		scene.flare.update(scene.camera,scene.atmosphere.sun_direction,scene.landscape.style_enabled,1.0)
	for i: int in range(10): await process_frame
	await RenderingServer.frame_post_draw
	print("SUN: uv=",scene.flare.screen_sun," strength=",scene.flare.current_strength)
	DirAccess.make_dir_recursive_absolute("res://logs")
	var suffix := "_angle" if angle else ""
	if gray: suffix += "_gray"
	if "--moving" in OS.get_cmdline_user_args(): suffix += "_moving"
	if "--sun" in OS.get_cmdline_user_args(): suffix += "_sun"
	if "--no-flare" in OS.get_cmdline_user_args(): suffix += "_no_flare"
	var path := "res://logs/visual_sample_%d%s.png" % [station,suffix]
	root.get_texture().get_image().save_png(path)
	print("Saved ", path)
	scene.queue_free()
	await process_frame
	quit()

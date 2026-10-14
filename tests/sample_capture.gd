extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://scenes/dev/visual_sample.tscn").instantiate()
	root.add_child(scene)
	var station := 445.0
	var angle := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--at="): station = float(argument.trim_prefix("--at="))
		if argument == "--angle": angle = true
	scene.jump_to(station)
	scene.show_hud = false
	for i: int in range(180):
		paused = false
		await physics_frame
	if angle:
		scene.set_process(false)
		var pose: Transform3D = scene.vehicle.global_transform
		scene.camera.position = pose * Vector3(5.4,3.0,7.2)
		scene.camera.look_at(pose.origin + Vector3.UP*0.4 - pose.basis.z*8)
	for i: int in range(10): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://logs")
	var path := "res://logs/visual_sample_%d%s.png" % [station,"_angle" if angle else ""]
	root.get_texture().get_image().save_png(path)
	print("Saved ", path)
	scene.queue_free()
	await process_frame
	quit()

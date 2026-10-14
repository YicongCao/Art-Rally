extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := "--stage" in OS.get_cmdline_user_args()
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn" if stage else "res://scenes/dev/driving_lab.tscn").instantiate()
	root.add_child(scene)
	var station := 8.0
	if stage:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--at="): station = float(argument.trim_prefix("--at="))
		scene.vehicle.request_reset(scene.generator.route.pose_at(station))
	for i: int in range(120): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://logs/sunset_ridge_%d.png" % station if stage else "res://logs/driving_lab.png"
	image.save_png(path)
	print("Saved ", path)
	scene.queue_free()
	await process_frame
	quit()

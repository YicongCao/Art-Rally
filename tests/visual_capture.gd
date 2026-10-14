extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://scenes/dev/driving_lab.tscn").instantiate()
	root.add_child(scene)
	for i: int in range(120): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://logs/driving_lab.png")
	print("Saved logs/driving_lab.png")
	scene.queue_free()
	await process_frame
	quit()

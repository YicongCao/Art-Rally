extends SceneTree

# Deterministic native-rendered preview, using existing project screenshots as backdrops.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	var background := TextureRect.new()
	background.texture = ImageTexture.create_from_image(Image.load_from_file("res://docs/previews/cinematic-title.jpg"))
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var race_image := ImageTexture.create_from_image(Image.load_from_file("res://docs/previews/cinematic-bridge.jpg"))
	var transition := RallyPageTransition.new()
	root.add_child(transition)
	await process_frame
	transition.wipe.set_process(false)
	transition.wipe.show()
	DirAccess.make_dir_recursive_absolute("/tmp/art-rally-flag-frames")
	for frame: int in range(86):
		var time := frame/60.0-.3
		var phase := 0.0
		if time>=0 and time<RallyPageTransition.FLAG_ENTER_SECONDS:
			phase = 1-pow(1-time/RallyPageTransition.FLAG_ENTER_SECONDS,3)
		elif time>=RallyPageTransition.FLAG_ENTER_SECONDS:
			background.texture = race_image
			phase = 1+pow(clampf((time-RallyPageTransition.FLAG_ENTER_SECONDS-RallyPageTransition.FLAG_HOLD_SECONDS)/RallyPageTransition.FLAG_EXIT_SECONDS,0,1),3)
		transition.wipe.phase = phase
		transition.wipe.cloth.set_shader_parameter("wind_time",frame/60.0)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_jpg("/tmp/art-rally-flag-frames/%03d.jpg"%frame,.92)
		if frame==25: image.save_jpg("res://docs/previews/flag-diagonal-entry.jpg",.95)
		if frame==43: image.save_jpg("res://docs/previews/flag-cloth-logo.jpg",.95)
	background.free()
	transition.free()
	await process_frame
	quit()

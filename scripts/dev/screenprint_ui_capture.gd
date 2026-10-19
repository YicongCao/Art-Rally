extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	# A native-rendered offscreen viewport avoids macOS clamping oversized windows
	# to the attached display's work area. Inspect the pixels, not requested size.
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://screenprint-ui-review/profile.json"
	viewport.add_child(app)
	AudioServer.set_bus_mute(0,true)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="拉力ART12345"
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1680,720)]:
		viewport.size=dimensions
		var directory := "res://docs/art-direction/screenprint/ui-%dx%d"%[dimensions.x,dimensions.y]
		DirAccess.make_dir_recursive_absolute(directory)
		for page: String in ["home","stages","vehicles","settings","guide","records","gallery","plate"]:
			if page=="plate":app.show_plate_setup(false)
			else:app.call("show_"+page)
			for frame: int in range(40):await process_frame
			await RenderingServer.frame_post_draw
			var pixels := viewport.get_texture().get_image()
			assert(pixels.get_size()==dimensions,"UI capture must match tested resolution")
			pixels.save_jpg(directory+"/"+page+".jpg",.9)
			print("UI CAPTURE: ",dimensions," ",page)
	viewport.queue_free()
	await process_frame
	quit()

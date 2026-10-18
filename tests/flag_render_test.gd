extends "res://tests/test_suite.gd"

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("This pixel-coverage test requires a native renderer")
		quit(1)
		return
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1680,720)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.color = Color.MAGENTA
		background.size = dimensions
		viewport.add_child(background)
		var transition := RallyPageTransition.new()
		viewport.add_child(transition)
		transition.wipe.set_process(false)
		transition.wipe.show()
		await process_frame
		for phase: float in [0.0,1.0,2.0]:
			transition.wipe.phase = phase
			for wind: float in [0.0,.4,.8]:
				transition.wipe.cloth.set_shader_parameter("wind_time",wind)
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				var exposed := 0
				var samples := 0
				for y: int in range(0,dimensions.y,17):
					for x: int in range(0,dimensions.x,17):
						var color := image.get_pixel(x,y)
						if color.r>.9 and color.b>.9 and color.g<.1: exposed+=1
						samples+=1
				check(exposed==0 if phase==1 else exposed==samples,"%s phase %.0f wind %.1f: correct rendered coverage"%[dimensions,phase,wind])
		viewport.free()
		await process_frame
	finish()

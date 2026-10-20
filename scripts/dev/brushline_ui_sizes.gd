extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var view := SubViewport.new()
	view.size=Vector2i(1920,1080)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.texture=view.get_texture()
	root.add_child(display)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://ui-sizes-%d/profile.json"%Time.get_ticks_usec()
	view.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="沪A·山野拉力016"
	AudioServer.set_bus_mute(0,true)
	for pixels: Vector2i in [Vector2i(1920,1080),Vector2i(2560,1080)]:
		view.size=pixels
		for screen: String in ["home","stages","vehicles","loading"]:
			match screen:
				"home":app.show_home()
				"stages":app.show_stages()
				"vehicles":app.show_vehicles()
				_:app._loading_page()
			await create_timer(.35).timeout
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_jpg("res://docs/brushline/%s-%d.jpg"%[screen,pixels.x],.9)
	view.queue_free()
	display.queue_free()
	await process_frame
	quit()

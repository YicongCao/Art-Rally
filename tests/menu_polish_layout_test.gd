extends "res://tests/test_suite.gd"

func _run() -> void:
	var view := SubViewport.new()
	view.size=Vector2i(1280,720)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.texture=view.get_texture()
	root.add_child(display)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://menu-polish-%d/profile.json"%Time.get_ticks_usec()
	view.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="BRUSHLINE"
	app.prefs.values.reduced_motion=true
	AudioServer.set_bus_mute(0,true)
	for pixels: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		view.size=pixels
		for page: String in ["stages","vehicles","loading"]:
			match page:
				"stages":app.show_stages()
				"vehicles":app.show_vehicles()
				_:app._loading_page()
			await create_timer(.3).timeout
			check(app.ui.find_children("*","ScrollContainer",true,false).is_empty(),"%s %d: no scrolling selection surface"%[page,pixels.x])
			var art_count := 0
			var bounds := Rect2(Vector2.ZERO,Vector2(pixels)).grow(-18)
			for control: Control in app.ui.find_children("*","Control",true,false):
				if control is RallyArtbookPanel:
					art_count+=1
					check(control.size.y>=120 and bounds.encloses(control.get_global_rect()),"%s %d: illustration stays fully inside screen"%[page,pixels.x])
				if control is Button and control.is_visible_in_tree():
					check(bounds.encloses(control.get_global_rect()),"%s %d: %s is reachable without scrolling"%[page,pixels.x,control.text])
			check(art_count==(2 if page=="loading" else 3),"%s: expected illustration count"%page)
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				view.get_texture().get_image().save_jpg("res://logs/menu-polish-%s-%d.jpg"%[page,pixels.x],.9)
	view.size=Vector2i(1280,720)
	app.practice=true
	await app.start_race()
	var scene: Node3D=app.race
	var labels: Array[String]=[]
	for button: Button in scene.pause_menu.find_children("*","Button",true,false):labels.append(button.text)
	check(not labels.any(func(text: String):return "更换车辆" in text or "计时 / 练习" in text),"Pause settings omit vehicle and mode shortcuts")
	scene.session.phase=RallyStageSession.Phase.RUNNING
	for frame: int in range(120):
		if paused:paused=false
		if scene.controls.blocked:scene.controls.resume()
		scene.pause_menu.hide()
		await physics_frame
	scene.trajectory.capture(scene.session.total_time(),scene.vehicle,true)
	var elapsed: float=scene.session.total_time()
	app.show_results({"elapsed":elapsed,"penalty":0,"total_time":elapsed,"splits":[],"outcome":{"eligible":false,"new_best":false}})
	check(scene.replay.active,"Real captured trajectory starts the results replay")
	var gradients := 0
	for control: Control in app.ui.find_children("*","Control",true,false):
		if control is TextureRect and control.texture is GradientTexture2D:gradients+=1
	check(gradients==0 and not app.backdrop.visible,"Results replay has no full-screen gradient veil")
	if DisplayServer.get_name()!="headless":
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_jpg("res://logs/menu-polish-results.jpg",.9)
	await app.leave_race()
	app.free()
	view.free()
	display.free()
	await process_frame
	finish()

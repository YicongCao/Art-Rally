extends "res://tests/test_suite.gd"


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"M6 release presentation requires a real render window")
		finish()
		return
	check(RallyFonts.TEXT.has_char("夕".unicode_at(0)) and RallyFonts.TEXT.has_char("驶".unicode_at(0)),"Bundled UI font contains required Chinese glyphs")
	check(RallyFonts.MONO.has_char("0".unicode_at(0)) and RallyFonts.MONO.has_char("R".unicode_at(0)),"Bundled numeric font contains dashboard glyphs")
	check(RallyFonts.TEXT.resource_path.begins_with("res://assets/fonts/") and RallyFonts.MONO.resource_path.begins_with("res://assets/fonts/"),"Release UI fonts are project resources rather than host system fallbacks")
	root.size = Vector2i(1920,1080)
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.preferences.set_value("volume",0)
	scene._apply_preferences()
	scene._set_autopilot_mode_name("vgamepad")
	for i: int in range(180):
		paused = false
		scene.controls.resume()
		scene.pause_menu.show_menu(false)
		await process_frame
	check(scene.game_hud.visible and scene.game_hud.model.label=="AUTO · PAD","1080p release HUD renders live automatic driving state")
	scene._safety_pause()
	root.size = Vector2i(960,540)
	for i: int in range(5): await process_frame
	var menu_panel: Control = scene.pause_menu.get_child(0).get_child(1).get_child(0)
	check(root.get_visible_rect().encloses(menu_panel.get_global_rect()),"Pause settings remain inside the minimum supported window")
	scene._restart()
	root.size = Vector2i(1920,1080)
	scene.session.phase = RallyStageSession.Phase.FINISHED
	scene.session.elapsed = 125.25
	scene.session.penalty = 5
	scene.session.next_gate = scene.session.gates.size()
	scene.session.progress = scene.session.gates[-1]
	scene._record_finish()
	for i: int in range(10):
		paused = false
		scene.pause_menu.show_menu(false)
		await process_frame
	check(scene.game_hud.model.new_record and scene.game_hud.model.best_label=="自动手柄参考","Release finish flow labels automatic reference results separately")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/m6_release.png")
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	finish()

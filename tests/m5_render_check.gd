extends "res://tests/test_suite.gd"


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"M5 audiovisual integration requires a real render window")
		finish()
		return
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.preferences.set_value("volume",0)
	scene._apply_preferences()
	for i: int in range(90):
		paused = false
		scene.controls.resume()
		scene.pause_menu.show_menu(false)
		await process_frame
	check(scene.feedback.players.engine.playing and scene.feedback.players.engine.get_playback_position()>0,"Real audio backend advances the synthesized engine stream")
	check(scene.game_hud.model.has("rpm") and scene.game_hud.visible,"Rendered HUD receives live vehicle model")
	scene._cycle_camera()
	scene._cycle_camera()
	for i: int in range(3): await process_frame
	check(scene.camera_mode==2 and scene.presentation.camera_rig.dashboard.visible,"Camera action reaches the cockpit presentation")
	scene._safety_pause()
	for i: int in range(5): await process_frame
	check(scene.feedback.players.engine.stream_paused and scene.pause_menu.visible,"Safety pause also pauses real audio and displays focusable settings")
	root.size = Vector2i(960,540)
	for i: int in range(5): await process_frame
	var menu_panel: Control = scene.pause_menu.get_child(0).get_child(1).get_child(0)
	var rect := menu_panel.get_global_rect()
	check(rect.position.x>=0 and rect.position.y>=0 and root.get_visible_rect().encloses(rect),"Settings panel remains inside the smaller game viewport")
	scene._restart()
	check(not paused and not scene.pause_menu.visible,"Restart leaves audiovisual pause cleanly")
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	finish()

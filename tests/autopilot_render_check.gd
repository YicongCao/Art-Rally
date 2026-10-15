extends "res://tests/test_suite.gd"


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"Autopilot presentation requires a real render window")
		finish()
		return
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.preferences.set_value("volume",0)
	scene._apply_preferences()
	scene._set_autopilot_mode_name("vgamepad")
	for i: int in range(240):
		paused = false
		await process_frame
	check(scene.auto_driver.pilot.progress>5 and scene.game_hud.model.label=="AUTO · PAD","Visible stage HUD follows the production virtual gamepad driver")
	check(scene.game_hud.model.target_speed>0 and is_finite(scene.game_hud.model.lateral_error),"HUD exposes finite automatic target speed and route error")
	scene._toggle_debug()
	for i: int in range(10): await process_frame
	check(scene.debug_panel.visible and scene.debug_panel.model.label=="AUTO · PAD","F9 diagnostics identify the live automatic source")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/autopilot_drive.png")
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	finish()

extends "res://tests/test_suite.gd"


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"Result presentation requires a real render window")
		finish()
		return
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.preferences.set_value("volume",0)
	scene._apply_preferences()
	scene.session.phase = RallyStageSession.Phase.FINISHED
	scene.session.elapsed = 125.25
	scene.session.penalty = 5
	scene.session.next_gate = scene.session.gates.size()
	scene.session.progress = scene.session.gates[-1]
	scene._record_finish()
	for i: int in range(10):
		paused = false
		scene.controls.resume()
		scene.pause_menu.show_menu(false)
		await process_frame
	check(scene.game_hud.model.new_record and is_equal_approx(scene.game_hud.model.best_time,130.25),"Finish HUD receives the newly saved personal best")
	check(is_equal_approx(scene.game_hud.model.elapsed,125.25) and scene.game_hud.model.best_label=="个人最佳","Finish HUD separates driving time penalty and result category")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/result_finish.png")
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	finish()

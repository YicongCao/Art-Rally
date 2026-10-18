extends "res://tests/test_suite.gd"


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"Vehicle selection render check needs a graphical window")
		finish()
		return
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.preferences.set_value("volume",0)
	scene._apply_preferences()
	scene._open_vehicle_selection()
	for i: int in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/vehicle_choice.png")
	check(paused and scene.vehicle_selector.visible,"Real pre-race menu is visible while physics is paused")
	scene.vehicle_selector.cards.FWD.set_pressed_no_signal(true)
	scene.vehicle_selector._select("FWD")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await process_frame
	enter.pressed = false
	Input.parse_input_event(enter)
	for i: int in range(3): await process_frame
	check(not scene.selecting_vehicle and not paused and scene.vehicle.drivetrain.config.drive_layout=="FWD","Enter confirms focused start button without immediately re-pausing gameplay")
	for i: int in range(240):
		paused = false
		scene.controls.blocked = false
		await physics_frame
	scene.controls.keys[KEY_S] = true
	for i: int in range(60):
		paused = false
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/reverse_hold.png")
	check(scene.reverse_assist.remaining()>0 and scene.reverse_assist.remaining()<=1,"Live reverse countdown reaches HUD during held brake")
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	finish()

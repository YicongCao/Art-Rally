extends "res://tests/test_suite.gd"

var scene: Node3D
var hint: int = 0


func _run() -> void:
	if DisplayServer.get_name() == "headless" or not "--test-defaults" in OS.get_cmdline_user_args():
		check(false, "README capture requires a graphical window and --test-defaults")
		finish()
		return
	DirAccess.make_dir_recursive_absolute("res://docs/previews")
	scene = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.preferences.set_value("volume", 0)
	scene._apply_preferences()
	if not "--debug-only" in OS.get_cmdline_user_args():
		await capture(493, 0, 520, "readme-gravel.jpg")
	await capture(1250, 0, 1281, "readme-debug.jpg", true)
	if not "--debug-only" in OS.get_cmdline_user_args():
		await capture(1740, 2, 1770, "readme-cockpit.jpg")
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	finish()


func capture(station: float, mode: int, target: float, filename: String, debug: bool = false) -> void:
	var route: RallyStageRoute = scene.generator.route
	scene.debug_panel.set_enabled(false)
	scene.set_physics_process(true)
	scene.vehicle.freeze = false
	scene.vehicle.command_source = scene._driver_command
	scene.vehicle.request_reset(route.pose_at(station))
	scene.camera_mode = mode
	scene.session.phase = RallyStageSession.Phase.RUNNING
	scene.session.countdown = 0
	scene.session.next_gate = 0
	while scene.session.gates[scene.session.next_gate] <= station: scene.session.next_gate += 1
	scene.session.progress = station
	scene.session.previous = route.pose_at(station).origin
	scene.session.projection_hint = route.index_at(station)
	scene.session.next_note = 0
	scene.session.current_note = ""
	scene.session.note_remaining = 0
	scene.session.elapsed = station / 13.0
	scene.session.penalty = 0
	scene.session.reset_count = 0
	for i: int in range(180):
		paused = false
		scene.controls.resume()
		scene.pause_menu.show_menu(false)
		await physics_frame
	if debug:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F9
		key.keycode = KEY_F9
		key.pressed = true
		Input.parse_input_event(key)
		for i: int in range(3): await process_frame
		var release: InputEventKey = key.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
		check(scene.debug_panel.visible, "Real F9 input opens visual debugging")
		if not scene.debug_panel.visible: return
	hint = route.index_at(station)
	scene.vehicle.command_source = driver
	var current := station
	for i: int in range(900):
		paused = false
		await physics_frame
		current = route.project(scene.vehicle.position, hint).s
		if current >= target: break
	check(current >= target and scene.session.reset_count == 0, filename + " reaches the shot through physical driving")
	check(scene.vehicle.linear_velocity.length() > 2, filename + " captures a moving car rather than a posed render")
	# Hold the last live state for render settling without displaying a pause overlay.
	scene.vehicle.freeze = true
	scene.set_physics_process(false)
	for i: int in range(15):
		paused = false
		scene.pause_menu.show_menu(false)
		await process_frame
	await RenderingServer.frame_post_draw
	if debug:
		check(scene.debug_panel.model.wheels.size() == 4 and scene.debug_panel.history.size() > 20, "Debug screenshot contains live four-wheel data and populated histories")
		check(not scene.game_hud.visible and scene.debug_visual.visible, "Visual debugger replaces HUD and enables world-space force arrows")
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(1280, 720), filename + " has the expected 16:9 frame")
	check(image.save_jpg("res://docs/previews/" + filename, 0.9) == OK, filename + " saves successfully")
	print("README CAPTURE: ", filename, " station=", current, " speed_kmh=", scene.vehicle.linear_velocity.length() * 3.6)
	if debug:
		root.size = Vector2i(960, 540)
		for i: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/debug_panel_960.png")
		check(scene.debug_panel.size == root.get_visible_rect().size, "Real smaller-window debug layout follows viewport anchors")
		root.size = Vector2i(1280, 720)


func driver(speed: float, _dt: float) -> DriverCommand:
	var command := DriverCommand.new()
	var route: RallyStageRoute = scene.generator.route
	var projection := route.project(scene.vehicle.position, hint)
	hint = projection.index
	var local: Vector3 = scene.vehicle.to_local(route.position_at(projection.s + 7))
	command.steer = clampf(atan2(5.2 * sin(atan2(local.x, -local.z)), 7) / 0.55, -1, 1)
	command.throttle = clampf((10 - speed) * 0.3 + 0.25, 0, 0.8)
	command.brake = clampf((speed - 11) * 0.3, 0, 0.6)
	return command

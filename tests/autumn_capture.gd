extends "res://tests/test_suite.gd"

# Reproducible real-render shots: place at a named station, then drive the next
# 40 m through the production autopilot and physics before capturing.
var scene: Node3D


func _run() -> void:
	if DisplayServer.get_name() == "headless" or not "--test-defaults" in OS.get_cmdline_user_args():
		check(false,"Autumn capture requires a graphics window and --test-defaults")
		finish()
		return
	DirAccess.make_dir_recursive_absolute("res://docs/previews")
	scene = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.preferences.set_value("volume",0)
	scene._apply_preferences()
	await capture(493,0,"autumn-gravel")
	await capture(1250,0,"autumn-mud")
	await capture(1740,2,"autumn-cockpit")
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	finish()


func resume_capture() -> void:
	paused = false
	if scene.controls.blocked: scene.controls.resume()
	scene.pause_menu.show_menu(false)


func capture(station: float,mode: int,filename: String) -> void:
	var route: RallyStageRoute = scene.generator.route
	scene._set_autopilot_mode_name("off")
	scene.vehicle.request_reset(route.pose_at(station))
	scene.camera_mode = mode
	scene.presentation.camera_rig.reset()
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
	scene.session.elapsed = station/13.0
	scene.session.penalty = 0
	scene.session.reset_count = 0
	for i: int in range(30):
		resume_capture()
		await process_frame
	scene.auto_driver.begin_run(route,scene.vehicle.position)
	scene._set_autopilot_mode_name("vgamepad")
	var start := Time.get_ticks_msec()
	var frames := 0
	while scene.session.progress < station+40 and Time.get_ticks_msec()-start < 20000:
		resume_capture()
		await process_frame
		frames += 1
	check(scene.session.progress>=station+40 and scene.session.reset_count==0,filename+" reaches shot under production autopilot")
	check(scene.vehicle.linear_velocity.length()>2,filename+" captures a moving car")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_jpg("res://docs/previews/"+filename+".jpg",0.94)==OK,filename+" saved")
	print("AUTUMN CAPTURE: ",filename," speed_kmh=",scene.vehicle.linear_velocity.length()*3.6," average_fps=",frames*1000.0/maxi(Time.get_ticks_msec()-start,1)," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

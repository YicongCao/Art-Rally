extends "res://tests/test_suite.gd"


func _run() -> void:
	history_checks()
	var drive := RallyDrivetrain.new()
	var command := DriverCommand.new()
	command.throttle = 0.6
	var wheels: Array[RallyWheelState] = []
	for i: int in range(4): wheels.append(RallyWheelState.new())
	drive.gear = 0
	drive.engine_omega = 6500 * TAU / 60
	var drag := 20 + drive.engine_omega * 0.045
	var expected := (drive.config.torque_at(6500) + drag) * 0.6 - drag
	drive.step(command, wheels, 1.0 / 480)
	check(is_equal_approx(drive.output_torque, expected) and drive.effective_throttle == 0.6, "Debug engine output measures actual net torque after internal drag")
	drive.auto_shift_cut = true
	drive.step(command, wheels, 1.0 / 480)
	check(drive.output_torque < 0 and drive.effective_throttle == 0, "Synchronization cut reports zero effective gas and engine braking, not requested pedal torque")
	drive.reset()
	check(drive.output_torque == 0 and drive.effective_throttle == 0, "Reset clears torque instrumentation")
	var car := RallyVehicle.new()
	root.add_child(car)
	var wheel := car.wheels[0]
	wheel.grounded = true
	wheel.load = 3000
	wheel.length = 0.3
	wheel.slip = 1.2
	wheel.slip_angle = 0.1
	wheel.omega = 20
	wheel.longitudinal_speed = 10
	wheel.longitudinal_force = 500
	wheel.lateral_force = 1000
	wheel.surface = RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[2], 0.07)
	wheel.water_force = Vector3(0, 0, 200)
	var data := RallyDebugPanel.data_for(car, Vector3(0.25, 0, -0.5))
	check(data.wheels.size() == 4 and data.wheels[0].surface == "Mud" and is_equal_approx(data.wheels[0].water_mm, 70), "Independent wheel snapshots preserve surface and water depth")
	check(data.wheels[0].load == 3000 and is_equal_approx(data.wheels[0].length_cm, 30) and is_equal_approx(data.wheels[0].travel, 0.5), "Suspension display uses actual load, length, and configured travel limits")
	check(data.wheels[0].slip == 1.2 and is_equal_approx(data.wheels[0].angle, rad_to_deg(0.1)), "Readouts preserve signed slip and degree units without clipping data")
	check(data.wheels[0].force.x > 0 and data.wheels[0].force.y < 0 and is_equal_approx(data.wheels[0].usage, data.wheels[0].force.length()), "Friction circle uses Fy / -Fx with the physical wet-grip force capacity")
	check(is_equal_approx(data.wheels[0].limit, RallyTireModel.capacity(3000, car.tire) * wheel.surface.grip(10)), "Friction-circle reference includes actual load sensitivity and wet surface grip")
	check(data.wheels[1].limit == 0 and data.wheels[1].force == Vector2.ZERO, "Airborne wheel has no friction-circle capacity or division by zero")
	check(data.front_share == 1 and data.left_share == 1 and data.g == Vector3(0.25, 0, -0.5), "Load balance and local G values use raw vehicle data")
	car.config.suspension_min = car.config.suspension_rest
	check(is_finite(RallyDebugPanel.data_for(car).wheels[0].travel), "Degenerate debug travel range cannot inject NaN into visualization")
	for layout: String in ["FWD", "AWD", "RWD"]:
		car.drivetrain.config.drive_layout = layout
		data = RallyDebugPanel.data_for(car)
		check(data.wheels[0].driven == (layout != "RWD") and data.wheels[2].driven == (layout != "FWD"), layout + " debug badges reflect actual driven axles")
	car.queue_free()
	await process_frame
	await scene_checks()
	await parity_run()
	finish()


func history_checks() -> void:
	var panel := RallyDebugPanel.new()
	panel.model = {"redline": 7600.0}
	var plot := Rect2(100, 100, 300, 120)
	panel.append_sample(Vector2(30, 2000), -50)
	check(panel.engine_history[0] == Vector2(2000, -50), "Engine history records measured RPM and signed torque together")
	var first := panel.engine_points(plot)
	check(first.rpm[0].x == plot.end.x and first.torque[0].x == plot.end.x, "Newest samples of both engine curves sit at the right edge")
	panel.append_sample(Vector2(50, 5000), 180)
	var next := panel.engine_points(plot)
	var shift := RallyDebugPanel.SAMPLE_INTERVAL / RallyDebugPanel.HISTORY_SECONDS * plot.size.x
	check(is_equal_approx(next.rpm[0].x, first.rpm[0].x - shift) and next.rpm[1].x == plot.end.x, "New driving samples move earlier data left at a fixed seconds-per-pixel scale")
	check(next.rpm[0].x == next.torque[0].x and next.rpm[1].x == next.torque[1].x, "RPM and torque curves share synchronized time coordinates")
	check(is_equal_approx(next.rpm[1].y, plot.end.y - 5000.0 / 7600 * plot.size.y), "RPM curve uses its independent redline-scaled vertical axis")
	check(is_equal_approx(next.torque[0].y, plot.end.y - 50.0 / 400 * plot.size.y), "Torque axis preserves engine braking below zero Nm")
	panel.append_sample(Vector2(100, 9000), 450)
	var clipped := panel.engine_points(plot)
	check(clipped.rpm[-1].y == plot.position.y and clipped.torque[-1].y == plot.position.y and panel.engine_history[-1] == Vector2(9000, 450), "Plot clipping does not change raw RPM or torque readings")
	for i: int in range(RallyDebugPanel.MAX_SAMPLES + 10): panel.append_sample(Vector2(i, i * 20), i)
	check(panel.history.size() == RallyDebugPanel.MAX_SAMPLES and panel.engine_history.size() == panel.history.size(), "All time series are trimmed together to bounded six-second histories")
	check(panel.engine_history[0].y == 10 and panel.engine_history[-1].y == RallyDebugPanel.MAX_SAMPLES + 9, "Scrolling retains the newest samples in chronological order")
	panel.clear_history()
	check(panel.history.is_empty() and panel.engine_history.is_empty(), "Reset clears torque, RPM and speed histories together")
	check(RallyDebugPanel.G_BALL_COLOR == RallyDebugPanel.RED, "G-G acceleration ball uses the red debug color")
	panel.free()


func scene_checks() -> void:
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	await ticks(240)
	check(not scene.debug_panel.visible, "Visual debugger is hidden on launch")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F9
	key.pressed = true
	scene.controls.active_device = 7
	scene.controls.axes[JOY_AXIS_TRIGGER_RIGHT] = 0.5
	scene.controls._unhandled_input(key)
	await ticks(30)
	check(scene.debug_panel.visible and not scene.game_hud.visible and scene.debug_visual.visible, "F9 opens graphical diagnostics, replaces HUD, and enables force vectors")
	check(scene.controls.active_device == 7 and scene.controls.axes[JOY_AXIS_TRIGGER_RIGHT] == 0.5, "Debug shortcut does not steal gamepad focus or clear held axes")
	key.echo = true
	scene.controls._unhandled_input(key)
	check(scene.debug_panel.visible, "Held F9 repeat cannot flicker the debug panel")
	key.echo = false
	for i: int in range(RallyDebugPanel.MAX_SAMPLES + 50): scene.debug_panel.append_sample(Vector2(i, i * 10))
	check(scene.debug_panel.history.size() == RallyDebugPanel.MAX_SAMPLES, "Six-second history has a bounded sample count")
	scene._toggle_pause()
	var count: int = scene.debug_panel.history.size()
	await ticks(30)
	check(scene.debug_panel.history.size() == count and scene.debug_panel.engine_history.size() == count, "Pause freezes both engine and chassis histories while leaving diagnostics visible")
	scene.controls._unhandled_input(key)
	check(not scene.debug_panel.visible, "F9 can hide frozen diagnostics while paused")
	scene._toggle_pause()
	scene.controls._unhandled_input(key)
	scene.controls.clear()
	await ticks(30)
	scene._toggle_telemetry()
	check(scene.telemetry_visible and not scene.debug_panel.visible, "Raw T telemetry and visual debugging are mutually exclusive")
	scene._toggle_debug()
	check(scene.debug_panel.visible and not scene.telemetry_visible, "Visual debugging replaces raw telemetry without stacking panels")
	scene._restart()
	await ticks(3)
	check(scene.debug_panel.history.size() < 3, "Vehicle reset clears history and acceleration discontinuities")
	scene._open_vehicle_selection()
	scene._toggle_debug()
	check(not scene.debug_panel.visible, "Vehicle selection hides diagnostics and blocks its toggle")
	scene._confirm_vehicle("AWD")
	scene.queue_free()
	paused = false
	await process_frame
	for viewport: Vector2 in [Vector2(960, 540), Vector2(1280, 720), Vector2(1024, 768), Vector2(2560, 1080)]:
		var layout := RallyHUD.layout_for(viewport)
		var corner: Vector2 = layout.offset + Vector2(1256, 716) * float(layout.scale)
		check(corner.x < viewport.x and corner.y < viewport.y, "Debug layout stays inside viewport %s" % viewport)


func parity_run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world, "Flat", Vector3(400, 1, 800), Vector3(0, -0.5, -200), Color.GRAY, true)
	var cars: Array[RallyVehicle] = []
	for x: float in [-5, 5]:
		var car := RallyVehicle.new()
		car.position = Vector3(x, 0.8, 0)
		world.add_child(car)
		cars.append(car)
	var panel := RallyDebugPanel.new()
	root.add_child(panel)
	panel.bind_vehicle(cars[0])
	panel.set_enabled(true)
	await ticks(360)
	for car: RallyVehicle in cars: car.command.throttle = 0.65
	await ticks(600)
	check(absf(cars[0].linear_velocity.length() - cars[1].linear_velocity.length()) < 0.005 and cars[0].drivetrain.gear == cars[1].drivetrain.gear, "Enabling diagnostics does not change physical acceleration or gearing")
	check(absf(cars[0].drivetrain.rpm() - cars[1].drivetrain.rpm()) < 1, "Debug instrumentation leaves engine dynamics unchanged")
	panel.set_enabled(false)
	await ticks(30)
	check(panel.history.is_empty(), "Hidden debugger stops sampling and releases its trace data")
	panel.queue_free()
	world.queue_free()
	await process_frame

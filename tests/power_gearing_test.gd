extends "res://tests/test_suite.gd"


func _run() -> void:
	var drive := RallyDrivetrain.new()
	drive.config = drive.config.duplicate()
	var command := DriverCommand.new()
	command.throttle = 1
	var wheels: Array[RallyWheelState] = []
	for i: int in range(4):
		var wheel := RallyWheelState.new()
		wheel.grounded = true
		wheel.load = 3000
		wheels.append(wheel)
	var peak_power := 0.0
	var peak_torque := 0.0
	for rpm: int in range(950, 7601, 10):
		var torque := drive.config.torque_at(rpm)
		peak_torque = maxf(peak_torque, torque)
		peak_power = maxf(peak_power, torque * rpm * TAU / 60)
	check(peak_power <= 200 * 735.49875 + 0.01 and peak_power > 199 * 735.49875, "Interpolated engine curve delivers at most 200 PS (147.1 kW)")
	check(is_equal_approx(peak_torque, 260), "Peak engine torque is 260 Nm")
	drive.gear = 0
	drive.engine_omega = 6500 * TAU / 60
	var initial_omega := drive.engine_omega
	drive.step(command, wheels, 1.0 / 480)
	var shaft_torque := (drive.engine_omega - initial_omega) * drive.config.engine_inertia * 480
	check(absf(shaft_torque - drive.config.torque_at(6500)) < 0.01, "Rated full-throttle torque is available after internal engine drag")
	for layout: String in ["FWD", "AWD", "RWD"]:
		drive.config.drive_layout = layout
		drive.reset()
		drive.engine_omega = 7200 * TAU / 60
		for wheel: RallyWheelState in wheels: wheel.omega = drive.engine_omega / drive.ratio()
		drive.begin_tick(command, 25.0 / 3.6, 0.34, wheels)
		check(drive.gear == 1 and drive.wheelspin > 0.35, layout + " wheelspin at 25 km/h cannot trigger an upshift")
		drive.gear = 6
		drive.engine_omega = 6767 * TAU / 60
		for wheel: RallyWheelState in wheels: wheel.omega = drive.engine_omega / drive.ratio()
		drive.begin_tick(command, 25.0 / 3.6, 0.34, wheels)
		check(drive.gear == 6 and drive.auto_shift_cut, layout + " spinning sixth gear lifts throttle instead of over-revving a downshift")
		var before := drive.engine_omega
		drive.step(command, wheels, 1.0 / 480)
		check(drive.engine_omega < before, layout + " synchronization cut removes engine power under held full throttle")
		for wheel: RallyWheelState in wheels: wheel.omega = 25.0 / 3.6 / 0.34
		drive.begin_tick(command, 25.0 / 3.6, 0.34, wheels)
		check(drive.gear == 1 and not drive.auto_shift_cut, layout + " returns directly to useful first gear once shaft speed is safe")
		drive.reset()
		var road_speed := 7000 * TAU / 60 / drive.ratio() * 0.34
		drive.engine_omega = 7100 * TAU / 60
		for wheel: RallyWheelState in wheels: wheel.omega = road_speed / 0.34
		drive.begin_tick(command, road_speed, 0.34, wheels)
		check(drive.gear == 2, layout + " normally coupled acceleration still upshifts")
		drive.reset()
		for wheel: RallyWheelState in wheels: wheel.omega = road_speed / 0.34
		drive.engine_omega = 7100 * TAU / 60
		for wheel: RallyWheelState in wheels: wheel.grounded = false
		drive.begin_tick(command, road_speed, 0.34, wheels)
		check(drive.gear == 1, layout + " airborne engine revs do not shift automatically")
		for wheel: RallyWheelState in wheels: wheel.grounded = true
		if layout != "AWD":
			for i: int in range(4): wheels[i].grounded = i >= 2 if layout == "FWD" else i < 2
			drive.begin_tick(command, road_speed, 0.34, wheels)
			check(drive.gear == 1, layout + " only undriven axle touching ground cannot trigger automatic shifts")
			for wheel: RallyWheelState in wheels: wheel.grounded = true
		command.handbrake = 1
		drive.begin_tick(command, road_speed, 0.34, wheels)
		check(drive.gear == 1, layout + " handbrake inhibits automatic shifting")
		command.handbrake = 0
		drive.reset()
		drive.gear = 6
		drive.engine_omega = 2000 * TAU / 60
		var high_speed := 65.0
		for wheel: RallyWheelState in wheels: wheel.omega = high_speed / 0.34
		drive.begin_tick(command, high_speed, 0.34, wheels)
		check(drive.gear == 6, layout + " high actual road speed prevents an inappropriate low-RPM downshift")
		drive.begin_tick(command, high_speed, 0.34, wheels, 5)
		check(drive.gear == 6 and drive.auto_shift_cut, layout + " shaft-speed guard rejects over-rev while sliding sideways")
		drive.reset()
		drive.gear = 6
		drive.engine_omega = 6767 * TAU / 60
		command.throttle = 0
		for wheel: RallyWheelState in wheels: wheel.omega = 55.0 / 3.6 / 0.34
		drive.begin_tick(command, 55.0 / 3.6, 0.34, wheels)
		check(drive.gear == 3, layout + " coasting downshift uses a relaxed road-RPM target despite high engine RPM")
		command.throttle = 1
	drive.reset()
	drive.config.drive_layout = "FWD"
	for i: int in range(4): wheels[i].omega = 20 if i < 2 else 150
	check(drive.driven_omega(wheels) == 20, "FWD shift sensing ignores undriven rear wheels")
	drive.config.drive_layout = "RWD"
	check(drive.driven_omega(wheels) == 150, "RWD shift sensing ignores undriven front wheels")
	drive.config.drive_layout = "AWD"
	check(drive.driven_omega(wheels, true) == 20, "AWD handbrake sensing uses decoupled front axle")
	drive.reset()
	drive.automatic = false
	drive.gear = 6
	drive.begin_tick(command, 0)
	check(drive.gear == 6 and not drive.auto_shift_cut, "Manual gearbox keeps driver-selected gear")
	drive.automatic = true
	command.shift = -1
	drive.begin_tick(command, 0)
	check(drive.gear == 5, "Manual shift command takes priority over automatic recovery")
	await mud_runs()
	finish()


func mud_runs() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var field := RallySurfaceField.new()
	field.base_id = 2
	world.add_child(field)
	var floor_body := GrayboxGeometry.box(world, "Mud", Vector3(500, 1, 1800), Vector3(0, -0.5, -400), Color.GRAY, true)
	field.attach(floor_body)
	for layout: String in ["FWD", "AWD", "RWD"]:
		var car := RallyVehicle.new()
		car.position = Vector3(0, 0.8, 0)
		car.drivetrain.config = car.drivetrain.config.duplicate()
		car.drivetrain.config.drive_layout = layout
		world.add_child(car)
		await ticks(360)
		car.command.throttle = 1
		var bad_shifts := 0
		var peak_rpm := 0.0
		for i: int in range(1440):
			await ticks(1)
			if car.linear_velocity.length() < 30.0 / 3.6 and car.drivetrain.gear > 2: bad_shifts += 1
			peak_rpm = maxf(peak_rpm, car.drivetrain.rpm())
		check(bad_shifts == 0, layout + " sustained full-throttle mud run has no high gears below 30 km/h")
		check(car.linear_velocity.length() > 20.0 / 3.6 and car.position.is_finite(), layout + " 200 PS car accelerates on physical mud contacts")
		print("POWER / GEAR METRIC: layout=", layout, " speed_kmh=", car.linear_velocity.length() * 3.6, " gear=", car.drivetrain.gear, " peak_rpm=", peak_rpm)
		car.request_reset(Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)))
		await ticks(360)
		car.linear_velocity = Vector3(0, 0, -25.0 / 3.6)
		car.drivetrain.gear = 6
		car.drivetrain.engine_omega = 6767 * TAU / 60
		for wheel: RallyWheelState in car.wheels: wheel.omega = car.drivetrain.engine_omega / car.drivetrain.ratio()
		car.command.throttle = 1
		await ticks(240)
		check(car.drivetrain.gear <= 2 and car.position.is_finite(), layout + " physical sixth-gear wheelspin recovers useful gearing within two seconds")
		car.queue_free()
		await ticks(2)
	world.queue_free()
	await process_frame

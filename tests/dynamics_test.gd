extends "res://tests/test_suite.gd"

var car: RallyVehicle
var world: Node3D
var metrics: Dictionary = {}
var keyboard_filter := DriverInputFilter.new()
var keyboard_tick: int = 0
var keyboard_sign: float = 1.0


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world, "Ground", Vector3(1000, 1, 2200), Vector3(0, -0.5, -600), Color.GRAY, true)
	await fresh()
	car.command.throttle = 1
	var steps := 0
	while car.linear_velocity.length() < 80.0 / 3.6 and steps < 2400:
		await ticks(1)
		steps += 1
	metrics["zero_to_80_seconds"] = steps / 120.0
	check(car.linear_velocity.length() >= 80.0 / 3.6 and car.drivetrain.gear >= 2, "Full-throttle run reaches 80 km/h and shifts automatically")
	var initial := car.position
	car.command.throttle = 0
	car.command.brake = 1
	steps = 0
	var max_pitch := 0.0
	while car.linear_velocity.length() > 0.15 and steps < 1200:
		await ticks(1)
		steps += 1
		max_pitch = maxf(max_pitch, absf(car.rotation.x))
	metrics["brake_80_distance_m"] = initial.distance_to(car.position)
	metrics["brake_max_pitch_deg"] = rad_to_deg(max_pitch)
	check(steps < 1200 and metrics.brake_80_distance_m > 10 and metrics.brake_80_distance_m < 100, "80 km/h braking stops within a bounded engineering envelope")
	check(max_pitch > 0.01 and max_pitch < 0.3, "Braking produces bounded chassis pitch")
	initial = car.position
	await ticks(1200)
	check(car.position.distance_to(initial) < 0.1, "High-speed braking transitions to stable parked contact")
	await fresh()
	car.command_source = circle_driver
	await ticks(2400)
	var yaw_rate := absf(car.angular_velocity.y)
	var turn_radius := car.linear_velocity.length() / maxf(yaw_rate, 0.001)
	metrics["circle_radius_m"] = turn_radius
	metrics["circle_speed_mps"] = car.linear_velocity.length()
	metrics["circle_roll_deg"] = rad_to_deg(car.rotation.z)
	check(turn_radius > 18 and turn_radius < 40 and car.position.is_finite(), "25 m target skidpad converges to a bounded turn radius")
	check(car.wheels[0].load + car.wheels[2].load > car.wheels[1].load + car.wheels[3].load, "Right-hand turn transfers load to outside left wheels")
	car.command_source = Callable()
	car.command = DriverCommand.new()
	car.command.handbrake = 1
	await ticks(48)
	var front_speed := absf(car.wheels[0].omega) + absf(car.wheels[1].omega)
	var rear_speed := absf(car.wheels[2].omega) + absf(car.wheels[3].omega)
	check(rear_speed < front_speed and car.angular_velocity.is_finite(), "Handbrake slows rear wheels without locking front axle")
	await fresh()
	car.command.throttle = 0.7
	await ticks(600)
	car.command.throttle = 0.25
	var min_yaw := 10.0
	var max_yaw := -10.0
	for i: int in range(720):
		car.command.steer = sin(float(i) / 120 * PI) * 0.12
		await ticks(1)
		min_yaw = minf(min_yaw, car.angular_velocity.y)
		max_yaw = maxf(max_yaw, car.angular_velocity.y)
	check(min_yaw < -0.03 and max_yaw > 0.03 and absf(car.rotation.z) < 0.4, "Slalom responds both ways with bounded roll")
	await fresh()
	car.command_source = keyboard_driver
	var crossing_count := 0
	var last_sign := 1.0
	for i: int in range(3600):
		await ticks(1)
		if keyboard_sign != last_sign:
			crossing_count += 1
			last_sign = keyboard_sign
	metrics["keyboard_slalom_crossings"] = crossing_count
	check(crossing_count >= 4 and car.position.is_finite() and absf(car.rotation.z) < 0.4, "Binary keyboard input with assistance completes repeated low-speed slalom")
	await fresh()
	car.command.throttle = 0.7
	await ticks(480)
	car.command.throttle = 0
	var speed_before_coast := car.linear_velocity.length()
	await ticks(240)
	check(car.linear_velocity.length() < speed_before_coast, "Coasting drivetrain and rolling resistance remove energy")
	car.command.brake = 1
	await ticks(600)
	car.command.brake = 0
	initial = car.position
	await ticks(1200)
	check(car.position.distance_to(initial) < 0.1, "Unbraked car remains at rest after braking without stale tire memory")
	var obstacle := GrayboxGeometry.box(world, "SingleSideBump", Vector3(0.7, 0.12, 1.2), Vector3(-0.8, 0.05, -20), Color.GRAY, true)
	await fresh()
	car.command.throttle = 0.65
	var difference := 0.0
	for i: int in range(900):
		await ticks(1)
		difference = maxf(difference, absf(car.wheels[0].length - car.wheels[1].length))
	metrics["single_bump_travel_difference_m"] = difference
	check(difference > 0.03 and car.position.is_finite() and car.position.y > 0.4, "Single-wheel bump excites suspension without tunneling or explosion")
	obstacle.queue_free()
	await ticks(2)
	var bumps: Array[Node3D] = []
	for i: int in range(6):
		bumps.append(GrayboxGeometry.box(world, "Wave", Vector3(8, 0.08, 1.8), Vector3(0, 0.025, -20 - i * 6), Color.GRAY, true))
	await fresh()
	car.command.throttle = 0.65
	var finite_run := true
	for i: int in range(1200):
		await ticks(1)
		finite_run = finite_run and car.position.is_finite() and car.position.y > 0.3 and absf(car.rotation.x) < 0.5
	check(finite_run and car.position.z < -55, "Continuous undulations remain bounded across repeated contacts")
	for bump: Node3D in bumps: bump.queue_free()
	await ticks(2)
	var ramp := GrayboxGeometry.box(world, "Jump", Vector3(8, 0.4, 14), Vector3(0, 0.85, -55), Color.GRAY, true, Vector3(8, 0, 0))
	await fresh()
	car.command.throttle = 0.85
	var airborne_seen := false
	var grounded_after := false
	for i: int in range(1200):
		await ticks(1)
		var grounded_count := 0
		for wheel: RallyWheelState in car.wheels:
			if wheel.grounded: grounded_count += 1
		if grounded_count == 0 and car.position.z < -45: airborne_seen = true
		if airborne_seen and grounded_count == 4: grounded_after = true
	check(airborne_seen and grounded_after and car.position.is_finite(), "Ramp launches vehicle and all four contacts recover after landing")
	ramp.queue_free()
	await ticks(2)
	car.request_reset(Transform3D(Basis(Vector3.FORWARD, PI), Vector3(0, 1, 0)))
	car.command = DriverCommand.new()
	await ticks(120)
	car.request_reset(Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)))
	await ticks(480)
	check(absf(car.rotation.z) < 0.02 and car.linear_velocity.length() < 0.1 and absf(car.wheels[0].relaxed_slip) < 0.01, "Overturned vehicle reset clears dynamic state")
	DirAccess.make_dir_recursive_absolute("res://logs")
	var report := FileAccess.open("res://logs/dynamics_metrics.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "\t"))
	print("DYNAMICS METRICS: ", JSON.stringify(metrics))
	world.queue_free()
	await process_frame
	finish()


func fresh() -> void:
	if is_instance_valid(car):
		car.queue_free()
		await ticks(2)
	car = RallyVehicle.new()
	car.position = Vector3(0, 0.8, 0)
	world.add_child(car)
	await ticks(360)


func circle_driver(speed: float, _dt: float) -> DriverCommand:
	var command := DriverCommand.new()
	command.steer = 0.19
	command.throttle = clampf(0.22 + (8.0 - speed) * 0.3, 0, 0.8)
	command.brake = clampf((speed - 8.5) * 0.2, 0, 0.5)
	return command


func keyboard_driver(speed: float, dt: float) -> DriverCommand:
	keyboard_tick += 1
	if car.position.x * keyboard_sign > 2.5: keyboard_sign *= -1
	var target_x := 3.0 * keyboard_sign
	var forward := -car.basis.z
	var desired_yaw := atan2(target_x - car.position.x, 12.0)
	var actual_yaw := atan2(forward.x, -forward.z)
	var error := wrapf(desired_yaw - actual_yaw, -PI, PI)
	var raw := DriverCommand.new()
	raw.steer = signf(error) if absf(error) > 0.04 else 0.0
	raw.throttle = 1.0 if speed < 5.0 else 0.0
	raw.brake = 1.0 if speed > 6.0 else 0.0
	return keyboard_filter.step(raw, speed, dt, true)

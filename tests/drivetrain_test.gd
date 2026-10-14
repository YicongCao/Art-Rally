extends "res://tests/test_suite.gd"


func _run() -> void:
	var drive := RallyDrivetrain.new()
	var command := DriverCommand.new()
	var wheels: Array[RallyWheelState] = []
	for i: int in range(4): wheels.append(RallyWheelState.new())
	check(not drive.request_shift(0, 20), "Cannot select neutral or reverse while moving")
	check(drive.request_shift(2, 0), "Sequential upshift accepted")
	command.throttle = 1
	var torque := drive.step(command, wheels, 1.0 / 480)
	check(absf(torque[0]) < 0.01 and drive.clutch == 0, "Shift interrupts clutch torque")
	check(not drive.request_shift(3, 0), "Second shift rejected until shift interval ends")
	drive.reset()
	for i: int in range(600): torque = drive.step(command, wheels, 1.0 / 480)
	check(drive.rpm() > 1000 and torque[0] > 0, "Engine inertia and automatic clutch build launch torque")
	var sum := torque[0] + torque[1] + torque[2] + torque[3]
	check(absf(sum - drive.clutch_torque * drive.ratio()) < 0.01, "Differentials conserve total input torque")
	var speeds := PackedFloat64Array([10, 100, 30, 30])
	torque = RallyDrivetrain.distribute(800, speeds, false, drive.config)
	check(torque[0] > torque[1] and absf(torque[0] - torque[1]) <= drive.config.axle_lock_limit * 2 + 0.01, "Axle limited slip opposes speed difference with finite lock torque")
	torque = RallyDrivetrain.distribute(0, speeds, false, drive.config)
	var power := 0.0
	for i: int in range(4): power += torque[i] * speeds[i]
	check(power <= 0, "Differential coupling dissipates relative wheel energy")
	torque = RallyDrivetrain.distribute(800, PackedFloat64Array([80, 80, 0, 0]), true, drive.config)
	check(is_zero_approx(torque[2] + torque[3]) and is_equal_approx(torque[0] + torque[1], 800), "Handbrake decouples rear drive from front axle")
	drive.reset()
	drive.engine_omega = 7200 * TAU / 60
	drive.begin_tick(DriverCommand.new(), 25)
	check(drive.gear == 2, "Automatic gearbox upshifts above threshold")
	drive.reset()
	drive.gear = 6
	drive.engine_omega = 7000 * TAU / 60
	check(not drive.request_shift(5, 50), "Downshift that would over-rev is rejected")
	drive.reset()
	drive.gear = 0
	for i: int in range(2000): drive.step(command, wheels, 1.0 / 480)
	check(drive.rpm() < drive.config.redline_rpm + 100, "Rev limiter prevents runaway neutral engine speed")
	drive.reset()
	for wheel: RallyWheelState in wheels: wheel.omega = 60
	drive.engine_omega = 60 * drive.ratio() - 20
	torque = drive.step(DriverCommand.new(), wheels, 1.0 / 480)
	check(torque[0] < 0, "Coasting wheels back-drive engine through clutch")
	finish()

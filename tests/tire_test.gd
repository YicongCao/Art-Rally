extends "res://tests/test_suite.gd"


func _run() -> void:
	var config := RallyVehicleConfig.new()
	var tire := RallyTireConfig.new()
	var wheel := RallyWheelState.new()
	check(RallyTireModel.solve(wheel, 500, 0, 1.0 / 480, config, tire) == Vector2.ZERO, "Airborne tire produces no contact force")
	check(wheel.omega > 0, "Airborne wheel still receives drive torque")
	wheel.grounded = true
	wheel.load = 3000
	wheel.longitudinal_speed = 15
	wheel.lateral_speed = 4
	wheel.omega = 70
	var force := RallyTireModel.solve(wheel, 500, 0, 1.0 / 480, config, tire)
	check(force.length() <= RallyTireModel.capacity(3000, tire) + 0.01 and force.y < 0, "Combined slip stays inside friction circle and opposes lateral slip")
	var stable := true
	for i: int in range(1000):
		wheel.longitudinal_speed = 0
		wheel.lateral_speed = 0
		force = RallyTireModel.solve(wheel, 0, 1500, 1.0 / 480, config, tire)
		stable = stable and is_finite(wheel.omega) and force.is_finite()
	check(stable and absf(wheel.omega) < 0.01, "Low-speed brake solve remains finite without wheel reversal")
	var peak := RallyTireModel.curve(1.0 / tire.longitudinal_stiffness, tire.longitudinal_stiffness)
	var sliding := RallyTireModel.curve(0.8, tire.longitudinal_stiffness)
	check(peak > sliding and sliding > 0.7, "Tire has a progressive peak and nonzero sliding plateau")
	check(is_equal_approx(RallyTireModel.curve(-0.2, 8), -RallyTireModel.curve(0.2, 8)), "Tire curve is sign-symmetric")
	check(RallyTireModel.capacity(6000, tire) > RallyTireModel.capacity(3000, tire) and RallyTireModel.capacity(6000, tire) < 2 * RallyTireModel.capacity(3000, tire), "Load sensitivity increases force sublinearly")
	wheel.reset()
	wheel.grounded = true
	wheel.load = 3000
	wheel.longitudinal_speed = 20
	wheel.lateral_speed = 2
	wheel.omega = 20 / config.wheel_radius
	RallyTireModel.solve(wheel, 0, 0, 1.0 / 480, config, tire)
	check(wheel.relaxed_angle > 0 and wheel.relaxed_angle < wheel.slip_angle, "Relaxation length delays force buildup at speed")
	var left := RallyWheelState.new()
	var right := RallyWheelState.new()
	left.grounded = true
	right.grounded = true
	left.load = 3000
	right.load = 3000
	left.compression = 0.2
	right.compression = 0.1
	RallySuspension.anti_roll(left, right, 5000)
	check(is_equal_approx(left.load + right.load, 6000) and left.load > right.load, "Anti-roll bar transfers support without creating total load")
	RallySuspension.anti_roll(left, right, 1000000)
	check(left.load >= 0 and right.load >= 0, "Anti-roll bar cannot generate tensile road contact")
	finish()

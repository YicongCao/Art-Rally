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
	finish()

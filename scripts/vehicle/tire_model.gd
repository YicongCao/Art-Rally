class_name RallyTireModel
extends RefCounted


static func capacity(load: float, tire: RallyTireConfig) -> float:
	return maxf(load, 0) * tire.friction


static func curve(slip: float, stiffness: float) -> float:
	return tanh(slip * stiffness)


static func solve(wheel: RallyWheelState, drive: float, brake: float, dt: float, config: RallyVehicleConfig, tire: RallyTireConfig) -> Vector2:
	var radius := config.wheel_radius
	var inertia := config.wheel_inertia
	var limit := capacity(wheel.load, tire)
	if not wheel.grounded or limit <= 0:
		wheel.omega = move_toward(wheel.omega + drive * dt / inertia, 0, brake * dt / inertia)
		wheel.longitudinal_force = 0
		wheel.lateral_force = 0
		wheel.slip = 0
		wheel.slip_angle = 0
		return Vector2.ZERO
	var denominator := maxf(absf(wheel.longitudinal_speed), tire.low_speed_reference)
	var effective_mass := config.body_mass / 4.0
	wheel.slip_angle = atan2(wheel.lateral_speed, denominator)
	var lateral := -curve(wheel.slip_angle, tire.lateral_stiffness) * limit
	lateral /= 1.0 + limit * tire.lateral_stiffness * dt / (denominator * effective_mass)
	# Implicit wheel/contact coupling avoids a stiff explicit tire spring at walking speed.
	var low := -limit
	var high := limit
	var force := Vector2.ZERO
	for iteration: int in range(16):
		var trial := (low + high) * 0.5
		var omega := move_toward(wheel.omega + (drive - trial * radius) * dt / inertia, 0, brake * dt / inertia)
		var slip := (omega * radius - wheel.longitudinal_speed - trial * dt / effective_mass) / denominator
		force = Vector2(curve(slip, tire.longitudinal_stiffness) * limit, lateral).limit_length(limit)
		if trial > force.x:
			high = trial
		else:
			low = trial
	force.x = (low + high) * 0.5
	force = force.limit_length(limit)
	wheel.omega = move_toward(wheel.omega + (drive - force.x * radius) * dt / inertia, 0, brake * dt / inertia)
	wheel.slip = (wheel.omega * radius - wheel.longitudinal_speed) / denominator
	wheel.longitudinal_force = force.x
	wheel.lateral_force = force.y
	return force

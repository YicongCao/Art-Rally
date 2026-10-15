class_name RallyTireModel
extends RefCounted


static func capacity(load: float, tire: RallyTireConfig) -> float:
	var sensitivity := clampf(pow(maxf(load, 1.0) / tire.reference_load, -tire.load_sensitivity), 0.65, 1.25)
	return maxf(load, 0) * tire.friction * sensitivity


static func curve(slip: float, stiffness: float, sliding_ratio: float = 0.78) -> float:
	var x := absf(slip) * stiffness
	var value := sin(x * PI * 0.5) if x <= 1.0 else sliding_ratio + (1.0 - sliding_ratio) * exp(-0.5 * pow(x - 1.0, 2))
	return signf(slip) * value


static func solve(wheel: RallyWheelState, drive: float, brake: float, dt: float, config: RallyVehicleConfig, tire: RallyTireConfig) -> Vector2:
	var radius := wheel.effective_radius if config.tire_contact_model=="COMPLIANT_PATCH" else config.wheel_radius
	var inertia := config.wheel_inertia
	var limit := capacity(wheel.load, tire) * wheel.surface.grip(wheel.longitudinal_speed)
	var longitudinal_stiffness := tire.longitudinal_stiffness * wheel.surface.longitudinal_scale
	var lateral_stiffness := tire.lateral_stiffness * wheel.surface.lateral_scale
	var sliding := clampf(tire.sliding_ratio * wheel.surface.sliding_scale, 0.1, 1.0)
	if not wheel.grounded or limit <= 0:
		wheel.omega = move_toward(wheel.omega + drive * dt / inertia, 0, brake * dt / inertia)
		wheel.longitudinal_force = 0
		wheel.lateral_force = 0
		wheel.slip = 0
		wheel.slip_angle = 0
		wheel.relaxed_slip = 0
		wheel.relaxed_angle = 0
		return Vector2.ZERO
	var denominator := maxf(absf(wheel.longitudinal_speed), tire.low_speed_reference)
	var effective_mass := config.body_mass / 4.0
	wheel.slip_angle = atan2(wheel.lateral_speed, denominator)
	# Fade transient tire memory near rest so it cannot sustain a parking oscillation.
	var moving := smoothstep(0.5, 3.0, absf(wheel.longitudinal_speed))
	var gain := lerpf(1.0, 1.0 - exp(-maxf(absf(wheel.longitudinal_speed), 1.0) * dt / tire.relaxation_length), moving)
	wheel.relaxed_angle = lerpf(wheel.relaxed_angle, wheel.slip_angle, gain)
	var lateral := -curve(wheel.relaxed_angle, lateral_stiffness, sliding) * limit
	lateral /= 1.0 + limit * lateral_stiffness * dt / (denominator * effective_mass)
	# Implicit wheel/contact coupling avoids a stiff explicit tire spring at walking speed.
	var low := -limit
	var high := limit
	var force := Vector2.ZERO
	for iteration: int in range(16):
		var trial := (low + high) * 0.5
		var omega := move_toward(wheel.omega + (drive - trial * radius) * dt / inertia, 0, brake * dt / inertia)
		var slip := (omega * radius - wheel.longitudinal_speed - trial * dt / effective_mass) / denominator
		var relaxed := lerpf(wheel.relaxed_slip, slip, gain)
		force = Vector2(curve(relaxed, longitudinal_stiffness, sliding) * limit, lateral).limit_length(limit)
		if trial > force.x:
			high = trial
		else:
			low = trial
	force.x = (low + high) * 0.5
	force = force.limit_length(limit)
	wheel.omega = move_toward(wheel.omega + (drive - force.x * radius) * dt / inertia, 0, brake * dt / inertia)
	wheel.slip = (wheel.omega * radius - wheel.longitudinal_speed) / denominator
	wheel.relaxed_slip = lerpf(wheel.relaxed_slip, (wheel.omega * radius - wheel.longitudinal_speed - force.x * dt / effective_mass) / denominator, gain)
	wheel.longitudinal_force = force.x
	wheel.lateral_force = force.y
	return force

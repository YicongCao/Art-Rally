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
	var patch_brush := config.tire_contact_model=="COMPLIANT_PATCH" and wheel.patch!=null and wheel.patch.grounded
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
		wheel.aligning_moment = 0
		wheel.slip_dissipation = 0
		return Vector2.ZERO
	var denominator := maxf(absf(wheel.longitudinal_speed), tire.low_speed_reference)
	var effective_mass := config.body_mass / 4.0
	wheel.slip_angle = atan2(wheel.lateral_speed, denominator)
	# Fade transient tire memory near rest so it cannot sustain a parking oscillation.
	var moving := smoothstep(0.5, 3.0, absf(wheel.longitudinal_speed))
	var transport_speed := maxf(maxf(absf(wheel.longitudinal_speed),absf(wheel.omega*radius)),1.0)
	var sigma_x := tire.relaxation_length
	var sigma_y := tire.relaxation_length
	if patch_brush:
		sigma_x = maxf(0.05,tire.longitudinal_relaxation_length+wheel.patch.half_length*tire.patch_relaxation_scale)
		sigma_y = maxf(0.05,tire.lateral_relaxation_length+wheel.patch.half_length*tire.patch_relaxation_scale)
	var gain_x := lerpf(1.0,1.0-exp(-transport_speed*dt/sigma_x),moving)
	var gain_y := lerpf(1.0,1.0-exp(-transport_speed*dt/sigma_y),moving)
	wheel.relaxed_angle = lerpf(wheel.relaxed_angle,wheel.slip_angle,gain_y)
	var lateral := -curve(wheel.relaxed_angle,lateral_stiffness,sliding)*limit
	var lateral_implicit_scale := 1.0/(1.0+limit*lateral_stiffness*dt/(denominator*effective_mass))
	lateral *= lateral_implicit_scale
	# Implicit wheel/contact coupling avoids a stiff explicit tire spring at walking speed.
	var low := -limit
	var high := limit
	var force := Vector2.ZERO
	for iteration: int in range(16):
		var trial := (low + high) * 0.5
		var omega := move_toward(wheel.omega + (drive - trial * radius) * dt / inertia, 0, brake * dt / inertia)
		var slip := (omega * radius - wheel.longitudinal_speed - trial * dt / effective_mass) / denominator
		var relaxed := lerpf(wheel.relaxed_slip,slip,gain_x)
		# The scalar aggregate curve keeps the wheel-speed solve cheap and monotonic.
		# Patch distribution is integrated once after this predictor converges.
		force = Vector2(curve(relaxed,longitudinal_stiffness,sliding)*limit,lateral).limit_length(limit)
		if trial > force.x:
			high = trial
		else:
			low = trial
	force.x = (low + high) * 0.5
	force = force.limit_length(limit)
	wheel.omega = move_toward(wheel.omega + (drive - force.x * radius) * dt / inertia, 0, brake * dt / inertia)
	wheel.slip = (wheel.omega * radius - wheel.longitudinal_speed) / denominator
	wheel.relaxed_slip = lerpf(wheel.relaxed_slip,(wheel.omega*radius-wheel.longitudinal_speed-force.x*dt/effective_mass)/denominator,gain_x)
	wheel.longitudinal_force = force.x
	wheel.lateral_force = force.y
	wheel.aligning_moment = 0.0
	var relative_slip := Vector2(wheel.longitudinal_speed-wheel.omega*radius,wheel.lateral_speed)
	wheel.slip_dissipation = maxf(0.0,-force.dot(relative_slip))
	return force


static func correct_patch_force(wheel: RallyWheelState,aggregate_force: Vector2,dt: float,config: RallyVehicleConfig,tire: RallyTireConfig) -> Vector2:
	if config.tire_contact_model!="COMPLIANT_PATCH" or wheel.patch==null or not wheel.patch.grounded or wheel.load<=0.0:
		return aggregate_force
	var response := _patch_response(wheel,wheel.relaxed_slip,wheel.relaxed_angle,tire)
	var denominator := maxf(absf(wheel.longitudinal_speed),tire.low_speed_reference)
	var limit := capacity(wheel.load,tire)*wheel.surface.grip(wheel.longitudinal_speed)
	var lateral_stiffness := tire.lateral_stiffness*wheel.surface.lateral_scale
	var lateral_scale := 1.0/(1.0+limit*lateral_stiffness*dt/(denominator*(config.body_mass/4.0)))
	var corrected := Vector2(response.x,response.y*lateral_scale)
	var correction := (corrected-aggregate_force).limit_length(capacity(wheel.load,tire)*0.5)
	corrected = aggregate_force+correction
	var radius := wheel.effective_radius
	wheel.omega += -(corrected.x-aggregate_force.x)*radius*dt/config.wheel_inertia
	wheel.longitudinal_force = corrected.x
	wheel.lateral_force = corrected.y
	wheel.aligning_moment = clampf(response.z*lateral_scale*tire.aligning_moment_gain,-tire.max_aligning_moment,tire.max_aligning_moment)
	var relative_slip := Vector2(wheel.longitudinal_speed-wheel.omega*radius,wheel.lateral_speed)
	wheel.slip_dissipation = maxf(0.0,-corrected.dot(relative_slip))
	return corrected


static func _patch_response(wheel: RallyWheelState,longitudinal_slip: float,lateral_angle: float,tire: RallyTireConfig) -> Vector3:
	var patch := wheel.patch
	var base_capacity := capacity(wheel.load,tire)
	var complex_flags := RallyWheelContactPatch.FLAG_PARTIAL_SUPPORT|RallyWheelContactPatch.FLAG_BRIDGE_REJECTED|RallyWheelContactPatch.FLAG_MIXED_SURFACE
	if patch.samples.size()==5 and (patch.flags&complex_flags)==0:
		return _uniform_patch_response(wheel,longitudinal_slip,lateral_angle,tire,base_capacity)
	var direction := signf(wheel.longitudinal_speed)
	if is_zero_approx(direction): direction = signf(wheel.omega)
	if is_zero_approx(direction): direction = 1.0
	var transport_mean := maxf(patch.half_length-direction*patch.pressure_center.x,0.001)
	var total := Vector2.ZERO
	var moment := 0.0
	for sample: RallyWheelContactSample in patch.samples:
		if not sample.supported or sample.pressure_weight<=0.0: continue
		var transport := clampf(patch.half_length-direction*sample.local.x,0.0,2.0*patch.half_length)
		var transport_scale := transport/transport_mean
		var local_limit := base_capacity*sample.pressure_weight*sample.surface.grip(wheel.longitudinal_speed)
		if local_limit<=0.0: continue
		var local_sliding := clampf(tire.sliding_ratio*sample.surface.sliding_scale,0.1,1.0)
		var trial := Vector2(
			longitudinal_slip*tire.longitudinal_stiffness*sample.surface.longitudinal_scale*PI*0.5,
			-lateral_angle*tire.lateral_stiffness*sample.surface.lateral_scale*PI*0.5
		)*local_limit*transport_scale
		if trial.length_squared()<=0.0: continue
		var utilization := trial.length()/local_limit
		var response_ratio := absf(curve(utilization,1.0,local_sliding))
		var local_force := trial.normalized()*response_ratio*local_limit
		total += local_force
		moment += sample.local.x*local_force.y-sample.local.y*local_force.x
	return Vector3(total.x,total.y,moment)


static func _uniform_patch_response(wheel: RallyWheelState,longitudinal_slip: float,lateral_angle: float,tire: RallyTireConfig,base_capacity: float) -> Vector3:
	var local_limit := base_capacity*wheel.surface.grip(wheel.longitudinal_speed)
	if local_limit<=0.0: return Vector3.ZERO
	var trial := Vector2(
		longitudinal_slip*tire.longitudinal_stiffness*wheel.surface.longitudinal_scale*PI*0.5,
		-lateral_angle*tire.lateral_stiffness*wheel.surface.lateral_scale*PI*0.5
	)
	if trial.length_squared()<=0.0: return Vector3.ZERO
	var utilization := trial.length()
	var sliding := clampf(tire.sliding_ratio*wheel.surface.sliding_scale,0.1,1.0)
	var response := trial.normalized()*absf(curve(utilization,1.0,sliding))*local_limit
	var trail := wheel.patch.half_length*0.33*(1.0-clampf(utilization,0.0,1.0))
	return Vector3(response.x,response.y,-trail*response.y)

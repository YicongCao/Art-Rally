extends "res://tests/test_suite.gd"


func _run() -> void:
	var config := RallyVehicleConfig.new()
	config.tire_contact_model = "COMPLIANT_PATCH"
	var tire := RallyTireConfig.new()
	var wheel := wheel_with_patch(tire)
	var zero := RallyTireModel._patch_response(wheel,0,0,tire)
	check(zero==Vector3.ZERO,"Patch brush produces no tangential force at zero slip")
	var small := RallyTireModel._patch_response(wheel,0.01,0.01,tire)
	check(small.x>0 and small.y<0 and small.length()>0,"Patch brush force signs follow longitudinal slip and lateral angle")
	var combined := RallyTireModel._patch_response(wheel,0.5,0.5,tire)
	check(Vector2(combined.x,combined.y).length()<=RallyTireModel.capacity(wheel.load,tire)*1.001,"Distributed local friction limits preserve the global capacity on uniform asphalt")
	check(absf(small.z)>0.01,"Transport through the patch creates a finite pneumatic aligning moment")
	var uniform_drive := RallyTireModel._patch_response(wheel,0.08,0,tire)
	wheel.patch.flags |= RallyWheelContactPatch.FLAG_MIXED_SURFACE
	wheel.patch.samples[1].surface = RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[2])
	wheel.patch.refresh_surface()
	var split_drive := RallyTireModel._patch_response(wheel,0.08,0,tire)
	check(split_drive.x>0 and split_drive.x<uniform_drive.x and split_drive.is_finite(),"Mixed-surface patch integrates local grip without averaging away the low-grip node")
	var original := tire.aligning_moment_gain
	tire.aligning_moment_gain = 1
	wheel.longitudinal_speed = 10
	wheel.lateral_speed = 0.4
	wheel.omega = 11/wheel.effective_radius
	var aggregate := Vector2.ZERO
	for i: int in range(24):
		wheel.omega = 11/wheel.effective_radius
		aggregate = RallyTireModel.solve(wheel,0,0,1.0/480.0,config,tire)
	RallyTireModel.correct_patch_force(wheel,aggregate,1.0/120.0,config,tire)
	check(wheel.relaxed_slip>0 and wheel.relaxed_angle>0,"Analytic patch relaxation builds finite longitudinal and lateral states")
	check(absf(wheel.aligning_moment)<=tire.max_aligning_moment and wheel.slip_dissipation>=0,"Aligning moment is bounded and reported slip power is dissipative")
	var stored := wheel.relaxed_slip
	wheel.grounded = false
	RallyTireModel.solve(wheel,0,0,1.0/480.0,config,tire)
	check(wheel.relaxed_slip==0 and stored>0,"Airborne wheel clears stale patch shear force")
	tire.aligning_moment_gain = original
	finish()


func wheel_with_patch(tire: RallyTireConfig) -> RallyWheelState:
	var wheel := RallyWheelState.new()
	wheel.grounded = true
	wheel.load = tire.reference_load
	wheel.loaded_radius = 0.34
	wheel.effective_radius = 0.34
	wheel.longitudinal_speed = 10
	wheel.surface = RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[0])
	wheel.patch.grounded = true
	wheel.patch.half_length = 0.06
	wheel.patch.half_width = 0.08
	for normalized: Vector2 in [Vector2.ZERO,Vector2(-0.7,0),Vector2(0.7,0),Vector2(0,-0.7),Vector2(0,0.7)]:
		var sample := wheel.patch.acquire_sample()
		sample.hit = true
		sample.supported = true
		sample.local = Vector2(normalized.x*wheel.patch.half_length,normalized.y*wheel.patch.half_width)
		sample.shape_weight = maxf(0.05,1.0-normalized.length_squared())
		sample.surface = RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[0])
	wheel.patch._update_pressure_weights(tire)
	wheel.patch.refresh_surface()
	return wheel

class_name RallySuspension
extends RefCounted


static func sample(wheel: RallyWheelState, mount: Vector3, state: PhysicsDirectBodyState3D, config: RallyVehicleConfig, tire: RallyTireConfig, body_rid: RID) -> void:
	var up := state.transform.basis.y
	var origin := state.transform * mount
	var heading := -state.transform.basis.z.rotated(up, wheel.steer)
	var compliant := config.tire_contact_model=="COMPLIANT_PATCH"
	if compliant:
		_sample_compliant(wheel,mount,state,config,tire,body_rid)
		return
	wheel.patch.begin_step()
	var contact_radius := config.wheel_radius
	var query := PhysicsRayQueryParameters3D.create(origin, origin - up * (config.suspension_rest + contact_radius), 1)
	query.exclude = [body_rid]
	var hit := state.get_space_state().intersect_ray(query)
	var support_length := INF
	if not hit.is_empty() and hit.normal.dot(up) > 0.25:
		support_length = origin.distance_to(hit.position) - contact_radius
	if config.contact_envelope:
		# Three longitudinal rays approximate the round tire envelope, not three springs.
		for fraction: float in [-0.6, 0.6]:
			var offset := contact_radius * fraction
			var reach := sqrt(contact_radius * contact_radius - offset * offset)
			var from := origin + heading * offset
			query.from = from
			query.to = from - up * (config.suspension_rest + reach)
			var candidate := state.get_space_state().intersect_ray(query)
			if candidate.is_empty() or candidate.normal.dot(up) <= 0.25: continue
			var length := from.distance_to(candidate.position) - reach
			if length < support_length:
				support_length = length
				hit = candidate
	var previous_deflection := wheel.radial_deflection
	var previous_compression := wheel.compression
	wheel.grounded = not hit.is_empty() and hit.normal.dot(up) > 0.25
	wheel.load = 0.0
	wheel.compression = 0.0
	wheel.length = config.suspension_rest
	wheel.loaded_radius = contact_radius
	wheel.effective_radius = contact_radius
	wheel.radial_damping_power = 0.0
	wheel.diagnostic_flags = 0
	if not wheel.grounded:
		wheel.radial_deflection = move_toward(previous_deflection,0.0,state.step*0.25)
		var reference_deflection := contact_radius-config.wheel_radius
		wheel.loaded_radius = contact_radius-wheel.radial_deflection
		wheel.effective_radius = clampf(config.wheel_radius+(reference_deflection-wheel.radial_deflection)*tire.effective_radius_deflection_ratio,wheel.loaded_radius,contact_radius)
		wheel.contact_age = 0.0
		wheel.surface = RallySurfaceSample.new()
		return
	wheel.point = hit.position
	wheel.normal = hit.normal
	wheel.surface = RallySurfaceQuery.footprint(hit.collider, wheel.point, heading, heading.cross(up))
	wheel.radial_deflection = 0.0
	wheel.length = clampf(support_length, 0, config.suspension_rest)
	wheel.compression = config.suspension_rest - wheel.length
	var velocity := state.linear_velocity + state.angular_velocity.cross(wheel.point - state.transform.origin - state.center_of_mass)
	var compress_speed := -velocity.dot(up)
	var damping := config.compression_damping if compress_speed > 0 else config.rebound_damping
	var bump := maxf(0, config.suspension_min - wheel.length)
	var force := config.spring_rate() * wheel.compression + damping * compress_speed + config.bump_stiffness * bump
	wheel.load = clampf(force, 0, config.body_mass * 9.81 * 3.0)
	wheel.contact_age += state.step


static func _sample_compliant(wheel: RallyWheelState,mount: Vector3,state: PhysicsDirectBodyState3D,config: RallyVehicleConfig,tire: RallyTireConfig,body_rid: RID) -> void:
	var previous_deflection := wheel.radial_deflection
	var previous_compression := wheel.compression
	var free_radius := RallyTireVerticalModel.unloaded_radius(config,tire)
	var patch := RallyContactSampler.sample(wheel,mount,state,config,tire,body_rid)
	wheel.patch = patch
	wheel.grounded = patch.grounded
	wheel.load = 0.0
	wheel.compression = 0.0
	wheel.length = config.suspension_rest
	wheel.loaded_radius = free_radius
	wheel.effective_radius = free_radius
	wheel.radial_damping_power = 0.0
	wheel.diagnostic_flags = patch.flags<<8
	if not patch.grounded:
		wheel.radial_deflection = move_toward(previous_deflection,0.0,state.step*0.25)
		var reference_deflection := free_radius-config.wheel_radius
		wheel.loaded_radius = free_radius-wheel.radial_deflection
		wheel.effective_radius = clampf(config.wheel_radius+(reference_deflection-wheel.radial_deflection)*tire.effective_radius_deflection_ratio,wheel.loaded_radius,free_radius)
		wheel.contact_age = 0.0
		wheel.surface = RallySurfaceSample.new()
		return
	var solved: Dictionary = RallyTireVerticalModel.solve(config.suspension_rest-patch.support_length,previous_deflection,previous_compression,state.step,config,tire)
	wheel.radial_deflection = solved.deflection
	wheel.compression = solved.compression
	wheel.length = config.suspension_rest-wheel.compression
	wheel.loaded_radius = solved.loaded_radius
	wheel.effective_radius = solved.effective_radius
	wheel.radial_damping_power = solved.damping_power
	wheel.diagnostic_flags |= int(solved.flags)
	patch.update_shape(config,tire,wheel.radial_deflection,RallyTireVerticalModel.elastic_force(wheel.radial_deflection,tire))
	patch.refresh_surface()
	wheel.point = patch.center
	wheel.normal = patch.normal
	wheel.surface = patch.surface
	var support_factor := smoothstep(0.1,0.75,patch.support_ratio)
	wheel.load = float(solved.load)*support_factor
	wheel.grounded = bool(solved.grounded) and wheel.load>0.0
	wheel.contact_age = wheel.contact_age+state.step if wheel.grounded else 0.0
	if not wheel.grounded: wheel.surface = RallySurfaceSample.new()


static func anti_roll(left: RallyWheelState, right: RallyWheelState, stiffness: float) -> void:
	if not left.grounded or not right.grounded: return
	var transfer := clampf((left.compression - right.compression) * stiffness, -left.load, right.load)
	left.load += transfer
	right.load -= transfer

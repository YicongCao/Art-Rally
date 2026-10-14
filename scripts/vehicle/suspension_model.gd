class_name RallySuspension
extends RefCounted


static func sample(wheel: RallyWheelState, mount: Vector3, state: PhysicsDirectBodyState3D, config: RallyVehicleConfig, body_rid: RID) -> void:
	var up := state.transform.basis.y
	var origin := state.transform * mount
	var heading := -state.transform.basis.z.rotated(up, wheel.steer)
	var query := PhysicsRayQueryParameters3D.create(origin, origin - up * (config.suspension_rest + config.wheel_radius), 1)
	query.exclude = [body_rid]
	var hit := state.get_space_state().intersect_ray(query)
	var support_length := INF
	if not hit.is_empty() and hit.normal.dot(up) > 0.25:
		support_length = origin.distance_to(hit.position) - config.wheel_radius
	if config.contact_envelope:
		# Three longitudinal rays approximate the round tire envelope, not three springs.
		for fraction: float in [-0.6, 0.6]:
			var offset := config.wheel_radius * fraction
			var reach := sqrt(config.wheel_radius * config.wheel_radius - offset * offset)
			var from := origin + heading * offset
			query.from = from
			query.to = from - up * (config.suspension_rest + reach)
			var candidate := state.get_space_state().intersect_ray(query)
			if candidate.is_empty() or candidate.normal.dot(up) <= 0.25: continue
			var length := from.distance_to(candidate.position) - reach
			if length < support_length:
				support_length = length
				hit = candidate
	wheel.grounded = not hit.is_empty() and hit.normal.dot(up) > 0.25
	wheel.load = 0.0
	wheel.compression = 0.0
	wheel.length = config.suspension_rest
	if not wheel.grounded:
		wheel.surface = RallySurfaceSample.new()
		return
	wheel.point = hit.position
	wheel.normal = hit.normal
	wheel.surface = RallySurfaceQuery.footprint(hit.collider, wheel.point, heading, heading.cross(up))
	wheel.length = clampf(support_length, 0, config.suspension_rest)
	wheel.compression = config.suspension_rest - wheel.length
	var velocity := state.linear_velocity + state.angular_velocity.cross(wheel.point - state.transform.origin - state.center_of_mass)
	var compress_speed := -velocity.dot(up)
	var damping := config.compression_damping if compress_speed > 0 else config.rebound_damping
	var bump := maxf(0, config.suspension_min - wheel.length)
	var force := config.spring_rate() * wheel.compression + damping * compress_speed + config.bump_stiffness * bump
	wheel.load = clampf(force, 0, config.body_mass * 9.81 * 3.0)


static func anti_roll(left: RallyWheelState, right: RallyWheelState, stiffness: float) -> void:
	if not left.grounded or not right.grounded: return
	var transfer := clampf((left.compression - right.compression) * stiffness, -left.load, right.load)
	left.load += transfer
	right.load -= transfer

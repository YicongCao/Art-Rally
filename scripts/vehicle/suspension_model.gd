class_name RallySuspension
extends RefCounted


static func sample(wheel: RallyWheelState, mount: Vector3, state: PhysicsDirectBodyState3D, config: RallyVehicleConfig, body_rid: RID) -> void:
	var up := state.transform.basis.y
	var origin := state.transform * mount
	var query := PhysicsRayQueryParameters3D.create(origin, origin - up * (config.suspension_rest + config.wheel_radius), 1)
	query.exclude = [body_rid]
	var hit := state.get_space_state().intersect_ray(query)
	wheel.grounded = not hit.is_empty() and hit.normal.dot(up) > 0.25
	wheel.load = 0.0
	wheel.compression = 0.0
	wheel.length = config.suspension_rest
	if not wheel.grounded:
		return
	wheel.point = hit.position
	wheel.normal = hit.normal
	wheel.length = clampf(origin.distance_to(wheel.point) - config.wheel_radius, 0, config.suspension_rest)
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

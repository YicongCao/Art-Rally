class_name RallyVehicle
extends RigidBody3D

signal reset_completed

@export var config: RallyVehicleConfig = preload("res://resources/vehicles/baseline.tres")
@export var tire: RallyTireConfig = preload("res://resources/vehicles/asphalt_tire.tres")
var drivetrain := RallyDrivetrain.new()
var wheels: Array[RallyWheelState] = []
var command := DriverCommand.new()
var command_source: Callable
var wheel_visuals: Array[Node3D] = []
var reset_pending: bool = false
var reset_pose := Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 12))
var physics_usec: int = 0
var simulation_tick: int = 0
var last_shift_requested: int = 0
var visual_deformation_gain: float = 1.0


func _ready() -> void:
	drivetrain.config = drivetrain.config.duplicate()
	mass = config.body_mass
	inertia = config.body_inertia
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = config.center_of_mass
	linear_damp = 0
	angular_damp = 0
	can_sleep = false
	continuous_cd = true
	collision_layer = 2
	collision_mask = 5
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = config.body_size
	collision.shape = shape
	add_child(collision)
	GrayboxGeometry.box(self, "Body", Vector3(1.72, 0.48, 3.85), Vector3.ZERO, Color("d16b36"))
	GrayboxGeometry.box(self, "Cabin", Vector3(1.4, 0.58, 1.7), Vector3(0, 0.5, 0.18), Color("293c48"))
	GrayboxGeometry.box(self, "HoodStripe", Vector3(0.32, 0.015, 1.15), Vector3(0, 0.245, -1.15), Color("e6d8b5"))
	for i: int in range(4):
		var wheel_state := RallyWheelState.new()
		wheel_state.loaded_radius = config.wheel_radius
		wheel_state.effective_radius = config.wheel_radius
		wheels.append(wheel_state)
		var pivot := Node3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = config.wheel_radius
		mesh.bottom_radius = config.wheel_radius
		mesh.height = 0.23
		mesh.radial_segments = 16
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("182027")
		mesh.material = material
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.rotation.z = PI * 0.5
		pivot.add_child(visual)
		for side: float in [-1.0, 1.0]:
			GrayboxGeometry.box(pivot, "Hub", Vector3(0.018, 0.16, 0.32), Vector3(side * 0.125, 0, 0), Color("c1c5be"))
		add_child(pivot)
		wheel_visuals.append(pivot)


func request_reset(pose: Transform3D) -> void:
	reset_pose = pose
	reset_pending = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var start := Time.get_ticks_usec()
	var did_reset := reset_pending
	if reset_pending:
		state.transform = reset_pose
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		for wheel: RallyWheelState in wheels: wheel.reset(config.wheel_radius)
		command = DriverCommand.new()
		drivetrain.reset()
		reset_pending = false
	if command_source.is_valid():
		command = command_source.call(state.linear_velocity.length(), state.step)
	command.sanitize()
	last_shift_requested = command.shift
	for i: int in range(4):
		wheels[i].steer = -command.steer * config.max_steer_radians if i < 2 else 0.0
		RallySuspension.sample(wheels[i], config.wheel_mount(i), state, config, tire, get_rid())
	RallySuspension.anti_roll(wheels[0], wheels[1], config.front_anti_roll)
	RallySuspension.anti_roll(wheels[2], wheels[3], config.rear_anti_roll)
	drivetrain.begin_tick(command, state.linear_velocity.length(), _driven_radius(command.handbrake>0.1), wheels, state.linear_velocity.dot(-state.transform.basis.z))
	command.shift = 0
	var brake_torques := PackedFloat64Array()
	for i: int in range(4):
		var wheel := wheels[i]
		var heading := -state.transform.basis.z.rotated(state.transform.basis.y, wheel.steer)
		wheel.forward = heading.slide(wheel.normal).normalized() if wheel.grounded else heading
		wheel.right = wheel.forward.cross(wheel.normal).normalized()
		var velocity := state.linear_velocity + state.angular_velocity.cross(wheel.point - state.transform.origin - state.center_of_mass)
		wheel.longitudinal_speed = velocity.dot(wheel.forward)
		wheel.lateral_speed = velocity.dot(wheel.right)
		var brake_share := config.front_brake_bias if i < 2 else 1.0 - config.front_brake_bias
		var brake_torque := command.brake * config.total_brake_torque * brake_share * 0.5
		if i >= 2: brake_torque += command.handbrake * config.handbrake_torque
		brake_torques.append(brake_torque)
	var forces: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var aligning_moments := PackedFloat64Array([0,0,0,0])
	# All four wheels share the same transmission state at each internal substep.
	var substep_dt := state.step/config.tire_substeps
	for substep: int in range(config.tire_substeps):
		var torques := drivetrain.step(command,wheels,substep_dt)
		for i: int in range(4):
			var solved := RallyTireModel.solve(wheels[i],torques[i],brake_torques[i],substep_dt,config,tire)
			forces[i] += solved/config.tire_substeps
			wheels[i].longitudinal_speed += solved.x * state.step / config.body_mass
			wheels[i].lateral_speed += solved.y * state.step / config.body_mass
	for i: int in range(4):
		var wheel := wheels[i]
		var tire_force := RallyTireModel.correct_patch_force(wheel,forces[i],state.step,config,tire)
		aligning_moments[i] = wheel.aligning_moment
		wheel.water_force = Vector3.ZERO
		if wheel.grounded:
			var roll := -(config.rolling_resistance + wheel.surface.rolling_extra) * wheel.load * tanh(wheel.longitudinal_speed / 0.5)
			wheel.water_force = wheel.surface.water_resistance(wheel.forward * wheel.longitudinal_speed + wheel.right * wheel.lateral_speed, wheel.load, state.step, config.body_mass / 4)
			var total := wheel.normal * wheel.load + wheel.forward * (tire_force.x + roll) + wheel.right * tire_force.y + wheel.water_force
			state.apply_force(total, wheel.point - state.transform.origin)
			if not is_zero_approx(aligning_moments[i]): state.apply_torque(wheel.normal*aligning_moments[i])
		wheel.longitudinal_force = tire_force.x
		wheel.lateral_force = tire_force.y
		wheel.spin = fmod(wheel.spin + wheel.omega * state.step, TAU)
		wheel_visuals[i].position = config.wheel_mount(i) - Vector3.UP * wheel.length
		wheel_visuals[i].rotation = Vector3(0, wheel.steer, 0)
		var tire_basis := Basis(Vector3.RIGHT,-wheel.spin)*Basis(Vector3.FORWARD,-PI*0.5)
		wheel_visuals[i].get_child(0).basis = tire_basis.scaled_local(tire_visual_scale(wheel))
		for hub_index: int in [1, 2]:
			wheel_visuals[i].get_child(hub_index).rotation.x = -wheel.spin
	state.apply_central_force(-0.5 * 1.225 * config.drag_coefficient_area * state.linear_velocity.length() * state.linear_velocity)
	simulation_tick += 1
	physics_usec = Time.get_ticks_usec() - start
	if did_reset: _complete_reset.call_deferred()


func _driven_radius(handbrake: bool) -> float:
	var indices: Array[int] = [0,1,2,3]
	if drivetrain.config.drive_layout=="FWD" or (drivetrain.config.drive_layout=="AWD" and handbrake): indices = [0,1]
	elif drivetrain.config.drive_layout=="RWD": indices = [2,3]
	var total := 0.0
	for index: int in indices:
		total += wheels[index].effective_radius if config.tire_contact_model=="COMPLIANT_PATCH" else config.wheel_radius
	return total/indices.size()


func tire_visual_scale(wheel: RallyWheelState) -> Vector3:
	if config.tire_contact_model!="COMPLIANT_PATCH" or visual_deformation_gain<=0.0: return Vector3.ONE
	var ratio := clampf(wheel.radial_deflection/maxf(config.wheel_radius,0.001)*visual_deformation_gain,0.0,0.25)
	return Vector3(1.0-ratio,1.0,1.0+ratio*0.35)


func _complete_reset() -> void:
	# Flush visual history after the physics server has synchronized the new pose.
	reset_physics_interpolation()
	reset_completed.emit()

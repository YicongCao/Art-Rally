class_name RallyVehicle
extends RigidBody3D

@export var config: RallyVehicleConfig = preload("res://resources/vehicles/baseline.tres")
var wheels: Array[RallyWheelState] = []
var command := DriverCommand.new()
var command_source: Callable
var wheel_visuals: Array[Node3D] = []
var reset_pending: bool = false
var reset_pose := Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 12))
var physics_usec: int = 0
var simulation_tick: int = 0


func _ready() -> void:
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
	shape.size = Vector3(1.65, 0.44, 3.7)
	collision.shape = shape
	add_child(collision)
	GrayboxGeometry.box(self, "Body", Vector3(1.72, 0.48, 3.85), Vector3.ZERO, Color("d16b36"))
	GrayboxGeometry.box(self, "Cabin", Vector3(1.4, 0.58, 1.7), Vector3(0, 0.5, 0.18), Color("293c48"))
	GrayboxGeometry.box(self, "HoodStripe", Vector3(0.32, 0.015, 1.15), Vector3(0, 0.245, -1.15), Color("e6d8b5"))
	for i: int in range(4):
		wheels.append(RallyWheelState.new())
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
		add_child(pivot)
		wheel_visuals.append(pivot)


func request_reset(pose: Transform3D) -> void:
	reset_pose = pose
	reset_pending = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var start := Time.get_ticks_usec()
	if reset_pending:
		state.transform = reset_pose
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		for wheel: RallyWheelState in wheels: wheel.reset()
		command = DriverCommand.new()
		reset_pending = false
		reset_physics_interpolation()
	if command_source.is_valid():
		command = command_source.call(state.linear_velocity.length(), state.step)
	command.sanitize()
	for i: int in range(4):
		var wheel := wheels[i]
		RallySuspension.sample(wheel, config.wheel_mount(i), state, config, get_rid())
		if wheel.grounded:
			state.apply_force(wheel.normal * wheel.load, wheel.point - state.transform.origin)
		wheel_visuals[i].position = config.wheel_mount(i) - Vector3.UP * wheel.length
	simulation_tick += 1
	physics_usec = Time.get_ticks_usec() - start

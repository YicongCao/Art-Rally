extends "res://tests/test_suite.gd"

var vehicle: RallyVehicle
var world: Node3D


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world, "Flat", Vector3(1000, 1, 1800), Vector3(0, -0.5, -400), Color.GRAY, true)
	vehicle = RallyVehicle.new()
	vehicle.position = Vector3(0, 0.85, 0)
	world.add_child(vehicle)
	await ticks(480)
	var load := 0.0
	for wheel: RallyWheelState in vehicle.wheels: load += wheel.load
	check(absf(load - vehicle.mass * 9.81) / (vehicle.mass * 9.81) < 0.05, "Suspension supports weight within five percent")
	check(vehicle.linear_velocity.length() < 0.05, "Suspension settles without persistent bounce")
	check(absf(vehicle.position.y - 0.69) < 0.04, "Static ride height matches spring equilibrium")
	var start := vehicle.position
	await ticks(1200)
	check(vehicle.position.distance_to(start) < 0.1, "Ten-second static drift below 0.1 m")
	vehicle.request_reset(Transform3D(Basis.IDENTITY, Vector3(0, 4, 0)))
	await ticks(3)
	var airborne := true
	for wheel: RallyWheelState in vehicle.wheels: airborne = airborne and not wheel.grounded and wheel.load == 0
	check(airborne, "Airborne wheels produce no support force")
	await ticks(480)
	check(vehicle.position.is_finite() and absf(vehicle.position.y - 0.69) < 0.05, "Drop and landing recover stable ride height")
	vehicle.command.throttle = 0.7
	await ticks(600)
	var speed := vehicle.linear_velocity.length()
	print("METRIC acceleration_speed_mps=", speed, " lateral_drift_m=", vehicle.position.x)
	check(speed > 8 and absf(vehicle.position.x) < 0.5, "Wheel torque accelerates car without asymmetric yaw")
	vehicle.command.throttle = 0
	vehicle.command.brake = 1
	await ticks(600)
	check(vehicle.linear_velocity.length() < 0.15, "Tire braking stops the car")
	start = vehicle.position
	await ticks(1200)
	check(vehicle.position.distance_to(start) < 0.1, "Brake hold remains stable for ten seconds")
	vehicle.request_reset(Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)))
	await ticks(240)
	vehicle.drivetrain.gear = -1
	vehicle.command.throttle = 0.4
	await ticks(240)
	check(vehicle.linear_velocity.z > 1, "Reverse gear drives backwards through wheel forces")
	vehicle.request_reset(Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)))
	await ticks(240)
	vehicle.command.throttle = 0.5
	vehicle.command.steer = 0.25
	await ticks(480)
	print("METRIC turn_position=", vehicle.position, " yaw=", vehicle.rotation.y, " rpm=", vehicle.drivetrain.rpm())
	check(vehicle.position.x > 1 and absf(vehicle.rotation.y) > 0.1, "Steering generates a right-hand turn from contact forces")
	world.queue_free()
	await process_frame
	finish()

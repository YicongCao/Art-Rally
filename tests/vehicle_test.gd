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
	world.queue_free()
	await process_frame
	finish()

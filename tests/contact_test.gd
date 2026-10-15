extends "res://tests/test_suite.gd"


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world, "Ground", Vector3(100, 1, 200), Vector3(0, -0.5, -60), Color.GRAY, true)
	var car := RallyVehicle.new()
	car.config = car.config.duplicate()
	car.config.tire_contact_model = "LEGACY"
	car.config.contact_envelope = true
	car.position.y = 0.8
	world.add_child(car)
	await ticks(360)
	var load := 0.0
	for wheel: RallyWheelState in car.wheels: load += wheel.load
	check(absf(load / (car.mass * 9.81) - 1) < 0.05, "Envelope contact does not multiply spring support")
	var block := GrayboxGeometry.box(world, "NarrowRidge", Vector3(5, 0.12, 0.10), Vector3(0, 0.05, -1.52), Color.GRAY, true)
	await ticks(2)
	check(car.wheels[0].point.z < -1.45, "Round envelope detects ridge ahead of center ray")
	block.queue_free()
	await ticks(240)
	car.command.throttle = 0.7
	GrayboxGeometry.box(world, "Bump", Vector3(8, 0.12, 0.3), Vector3(0, 0.05, -20), Color.GRAY, true)
	await ticks(900)
	check(car.position.z < -25 and car.position.is_finite() and absf(car.rotation.x) < 0.4, "Envelope crosses short obstacle without launch instability")
	world.queue_free()
	await process_frame
	finish()

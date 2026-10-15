extends "res://tests/test_suite.gd"


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world,"Flat",Vector3(1000,1,1800),Vector3(0,-0.5,-400),Color.GRAY,true)
	var vehicle := RallyVehicle.new()
	vehicle.config = vehicle.config.duplicate()
	vehicle.config.tire_contact_model = "COMPLIANT_PATCH"
	vehicle.tire = vehicle.tire.duplicate()
	vehicle.position = Vector3(0,0.85,0)
	world.add_child(vehicle)
	await ticks(600)
	var total_load := 0.0
	var all_compliant := true
	for wheel: RallyWheelState in vehicle.wheels:
		total_load += wheel.load
		all_compliant = all_compliant and wheel.grounded and wheel.radial_deflection>0.005 and wheel.loaded_radius<=wheel.effective_radius and wheel.effective_radius<=RallyTireVerticalModel.unloaded_radius(vehicle.config,vehicle.tire)
	check(absf(total_load-vehicle.mass*9.81)/(vehicle.mass*9.81)<0.05,"Compliant series suspension supports vehicle weight within five percent")
	check(all_compliant,"Every grounded wheel reports finite tire deflection and ordered radii")
	check(absf(vehicle.position.y-0.69)<0.04,"Nominal loaded-radius calibration preserves approved ride height")
	var start := vehicle.position
	await ticks(1200)
	check(vehicle.position.distance_to(start)<0.1 and vehicle.linear_velocity.length()<0.05,"Compliant contact remains stable for ten seconds")
	vehicle.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,4,0)))
	await ticks(3)
	var airborne := true
	for wheel: RallyWheelState in vehicle.wheels:
		airborne = airborne and not wheel.grounded and wheel.load==0
	check(airborne,"Airborne compliant tires release unilateral support")
	await ticks(480)
	check(vehicle.position.is_finite() and absf(vehicle.position.y-0.69)<0.05,"Compliant drop and landing recover stable ride height")
	vehicle.command.throttle = 0.7
	await ticks(600)
	check(vehicle.linear_velocity.length()>8 and absf(vehicle.position.x)<0.5,"Effective rolling radius preserves straight-line acceleration symmetry")
	vehicle.command.throttle = 0
	vehicle.command.brake = 1
	await ticks(600)
	check(vehicle.linear_velocity.length()<0.15,"Compliant wheel forces brake to a stable stop")
	world.queue_free()
	await process_frame
	finish()

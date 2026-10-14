extends "res://tests/test_suite.gd"


func _run() -> void:
	var car := RallyVehicle.new()
	root.add_child(car)
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := RallyCameraRig.new()
	rig.build(camera)
	for mode: int in range(3):
		rig.update(camera,car,mode,false,false,0.016)
		check(camera.position.is_finite() and rig.dashboard.visible==(mode==2),"Camera mode %d has finite pose and correct dashboard visibility"%mode)
	var fixed := camera.position
	rig.update(camera,car,2,false,false,0.1)
	check(camera.position.is_equal_approx(fixed),"Disabled cockpit motion adds no artificial vibration")
	car.command.steer = 0.5
	rig.update(camera,car,2,false,false,0.016)
	check(rig.steering_wheel.rotation.z<0,"Cockpit steering wheel follows actual steering command")
	car.queue_free()
	camera.queue_free()
	await process_frame
	finish()

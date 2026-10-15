extends "res://tests/test_suite.gd"


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world,"Flat",Vector3(1000,1,1800),Vector3(0,-0.5,-400),Color.GRAY,true)
	var four := car_with_substeps(4,Vector3(-4,0.85,0))
	var eight := car_with_substeps(8,Vector3(4,0.85,0))
	world.add_child(four)
	world.add_child(eight)
	await ticks(480)
	four.command.throttle = 1
	eight.command.throttle = 1
	await ticks(600)
	var speed_difference := absf(four.linear_velocity.length()-eight.linear_velocity.length())/maxf(four.linear_velocity.length(),0.1)
	var four_brake_start := four.position
	var eight_brake_start := eight.position
	four.command.throttle = 0
	eight.command.throttle = 0
	four.command.brake = 1
	eight.command.brake = 1
	await ticks(720)
	var four_distance := four_brake_start.distance_to(four.position)
	var eight_distance := eight_brake_start.distance_to(eight.position)
	var distance_difference := absf(four_distance-eight_distance)/maxf(four_distance,0.1)
	check(speed_difference<0.02,"Four and eight tire substeps keep acceleration within two percent")
	check(distance_difference<0.02 and four.linear_velocity.length()<0.15 and eight.linear_velocity.length()<0.15,"Four and eight tire substeps keep braking distance within two percent")
	world.queue_free()
	await process_frame
	finish()


func car_with_substeps(count: int,position: Vector3) -> RallyVehicle:
	var car := RallyVehicle.new()
	car.config = car.config.duplicate()
	car.config.tire_contact_model = "COMPLIANT_PATCH"
	car.config.tire_substeps = count
	car.tire = car.tire.duplicate()
	car.position = position
	return car

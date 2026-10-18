extends "res://tests/test_suite.gd"
var world: Node3D
func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world,"Road",Vector3(1000,1,1000),Vector3(0,-.5,0),Color.GRAY,true)
	var report := {}
	for id: String in RallyContentCatalog.VEHICLES:
		var runs: Array = []
		for balanced: bool in [false,true]:
			var definition := RallyContentCatalog.vehicle(id)
			var car := RallyVehicle.new()
			car.config = definition.physics_config()
			car.config.corner_brake_balance = balanced
			car.drivetrain.config = definition.drivetrain_config()
			world.add_child(car)
			car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,.8,0)))
			await ticks(180)
			car.linear_velocity = Vector3(0,0,-24)
			for wheel: RallyWheelState in car.wheels: wheel.omega=24/car.config.wheel_radius
			car.drivetrain.gear = 3
			car.drivetrain.engine_omega = 24/car.config.wheel_radius*car.drivetrain.ratio()
			car.command.brake = .95
			car.command.steer = .18
			var max_slip := 0.0
			var yaw := 0.0
			var front_slip := 0.0
			for i: int in range(150):
				await ticks(1)
				var local := car.basis.inverse()*car.linear_velocity
				max_slip=maxf(max_slip,absf(atan2(local.x,maxf(1,-local.z))))
				yaw+=absf(car.angular_velocity.y)/120
				front_slip+=absf(car.wheels[0].slip)/150
			runs.append({"balanced":balanced,"yaw_degrees":rad_to_deg(yaw),"max_slip_degrees":rad_to_deg(max_slip),"front_slip":front_slip,"speed":car.linear_velocity.length()})
			check(car.position.is_finite() and absf(car.rotation.z)<.3 and max_slip<.55,id+" braking turn remains upright with bounded sideslip")
			if balanced:
				car.command.brake = 0
				car.command.throttle = .3
				for i: int in range(240):
					var local := car.basis.inverse()*car.linear_velocity
					car.command.steer=clampf(local.x/maxf(-local.z,1)/.55,-.2,.2)
					await ticks(1)
				var recovered := car.basis.inverse()*car.linear_velocity
				check(absf(atan2(recovered.x,maxf(-recovered.z,1)))<.14 and car.basis.y.dot(Vector3.UP)>.9,id+" modest countersteer and throttle recover the braking slide")
			car.free()
			await process_frame
		report[id]=runs
		check(runs[1].yaw_degrees>runs[0].yaw_degrees*1.03,id+" corner brake balance restores turn-in under heavy braking")
		check(runs[1].front_slip<runs[0].front_slip,id+" front lock-up decreases")
	print("BRAKE COMPARISON: ",JSON.stringify(report))
	world.free()
	await process_frame
	finish()

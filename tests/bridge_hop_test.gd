extends "res://tests/test_suite.gd"
func _run() -> void:
	for id: String in RallyContentCatalog.STAGES:
		if id in ["misty_highlands","redrock_canyon"]:
			check(RallyContentCatalog.stage(id).river_crossings.is_empty(),id+" has no river bridge hop")
			continue
		var world := Node3D.new()
		root.add_child(world)
		var generator := RallyStageGenerator.new()
		generator.definition = RallyContentCatalog.stage(id)
		world.add_child(generator)
		var car := RallyVehicle.new()
		car.config = RallyContentCatalog.vehicle("A240").physics_config()
		world.add_child(car)
		var crossing: Vector3 = generator.definition.river_crossings[0]
		var start := crossing.x-crossing.y*.5-22
		car.request_reset(generator.route.pose_at(start))
		await ticks(180)
		car.linear_velocity = generator.route.tangent_at(start)*24
		for wheel: RallyWheelState in car.wheels: wheel.omega=24/car.config.wheel_radius
		car.drivetrain.gear = mini(3,car.drivetrain.config.ratios.size())
		car.drivetrain.engine_omega=24/car.config.wheel_radius*car.drivetrain.ratio()
		var pilot := RallyRoutePilot.new()
		pilot.reset(generator.route,car.position)
		car.command_source = func(speed: float,_dt: float) -> DriverCommand:
			var command := pilot.step(generator.route,car,speed)
			command.throttle=.15
			command.brake=0
			return command
		var air := 0
		var landed := false
		for i: int in range(480):
			await ticks(1)
			var grounded := 0
			for wheel: RallyWheelState in car.wheels:
				if wheel.grounded: grounded+=1
			if grounded==0: air+=1
			if air>0 and grounded>=3: landed=true
		print("BRIDGE HOP ",id," air=",air/120.0," landed=",landed)
		check(air>0 and air<150,id+" bridge creates a small bounded hop at 86 km/h")
		check(landed and car.basis.y.dot(Vector3.UP)>.75,id+" bridge landing remains upright")
		world.free()
		await process_frame
	finish()

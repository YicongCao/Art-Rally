extends "res://tests/test_suite.gd"
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var generator := RallyStageGenerator.new()
	world.add_child(generator)
	var car := RallyVehicle.new()
	world.add_child(car)
	var pilot := RallyRoutePilot.new()
	for crest: Vector3 in generator.definition.crests:
		car.command_source = Callable()
		car.request_reset(generator.route.pose_at(crest.x-24))
		await ticks(160)
		pilot.reset(generator.route,car.position)
		car.linear_velocity = generator.route.tangent_at(crest.x-24)*23
		for wheel: RallyWheelState in car.wheels: wheel.omega=23/car.config.wheel_radius
		car.command_source = func(speed: float,dt: float) -> DriverCommand:
			var command := pilot.step(generator.route,car,speed)
			command.throttle = .2
			command.brake = 0
			return command
		var air_ticks := 0
		var landed := false
		for i: int in range(480):
			await ticks(1)
			var grounded := 0
			for wheel: RallyWheelState in car.wheels:
				if wheel.grounded: grounded+=1
			if grounded==0: air_ticks+=1
			if air_ticks>0 and grounded>=3: landed=true
		print("JUMP ",crest.x," airtime=",air_ticks/120.0," landed=",landed)
		check(air_ticks>2,"Crest %d actually lifts all four wheels at approach speed"%crest.x)
		check(landed and car.position.is_finite() and car.basis.y.dot(Vector3.UP)>.6,"Crest %d allows a stable landing"%crest.x)
	world.queue_free()
	await process_frame
	finish()

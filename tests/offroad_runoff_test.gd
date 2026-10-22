extends "res://tests/test_suite.gd"
# Off-road runoff: beyond the 22 m road apron the visible terrain must collide, so
# a car that leaves the road keeps ground contact and brakes to a stop. The
# highland cliff side keeps its intended open drop.
func _run() -> void:
	for id: String in RallyContentCatalog.STAGES:
		var generator := RallyStageGenerator.new()
		generator.definition=RallyContentCatalog.stage(id)
		root.add_child(generator)
		var land := RallyStageScenery.new()
		root.add_child(land)
		land.build(generator)
		await ticks(2)
		var route := generator.route
		var space := land.get_world_3d().direct_space_state
		var misses := 0
		var gaps := 0
		var samples := 0
		for station: int in range(40,int(route.length)-40,37):
			if absf(route.definition.mountain_side_at(station))>.01: continue
			for side: float in [-1,1]:
				for lateral: float in [6.0,14.0,20.0,22.5,26.0,34.0,48.0]:
					var at := route.position_at(station)+route.rights[route.index_at(station)]*side*(route.width_at(station)*.5+lateral)
					var ground := land.rendered_height_at(at.x,at.z)
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,ground+30,at.z),Vector3(at.x,ground-30,at.z),1))
					samples+=1
					if hit.is_empty(): misses+=1
					# Inside 22 m the road chunk's own apron is the authoritative collider
					# and may sit up to ~2 m below the visual terrain on steep banks.
					elif float(hit.position.y)<ground-(2.5 if lateral<16 else .6): gaps+=1
		check(misses==0,id+" runoff terrain collides everywhere inside the recovery boundary (%d/%d misses)"%[misses,samples])
		check(gaps==0,id+" runoff collision follows the visible ground (%d gaps)"%gaps)
		if id!="misty_highlands":
			var body := land.dressing.get_node_or_null("RunoffTerrainCollision") as StaticBody3D
			check(body!=null and int(body.get_meta("surface_id"))==generator.definition.shoulder_surface,id+" runoff uses the stage shoulder surface")
		# Leave the road at 90 km/h, 20 degrees outward, and brake fully.
		var def := RallyContentCatalog.vehicle("R200")
		var car := RallyVehicle.new()
		car.config=def.physics_config()
		car.drivetrain.config=def.drivetrain_config()
		root.add_child(car)
		var stopped := 0
		var trials := 0
		for station: float in [route.length*.3,route.length*.55,route.length*.8]:
			if absf(route.definition.mountain_side_at(station))>.01: continue
			for side: float in [-1,1]:
				var pose := route.pose_at(station,0)
				var heading := (-pose.basis.z).rotated(Vector3.UP,-side*deg_to_rad(20))
				heading.y=0
				heading=heading.normalized()
				car.request_reset(Transform3D(Basis.looking_at(heading,Vector3.UP),land.ground_at(station,side*(route.width_at(station)*.5-.6))+Vector3.UP*.8))
				await ticks(60)
				car.linear_velocity=heading*25.0
				for wheel: RallyWheelState in car.wheels: wheel.omega=25.0/car.config.wheel_radius
				trials+=1
				for frame: int in range(120*8):
					car.command.throttle=0
					car.command.brake=1
					car.command.steer=0
					await ticks(1)
					if car.linear_velocity.length()<.6:
						stopped+=1
						break
		check(stopped==trials,id+" a car leaving the road at 90 km/h brakes to a stop (%d/%d)"%[stopped,trials])
		car.free()
		land.free()
		generator.free()
		await process_frame
	finish()

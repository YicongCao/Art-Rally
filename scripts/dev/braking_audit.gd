extends SceneTree
var world: Node3D
var samples: Array = []
func _initialize() -> void: run.call_deferred()
func ticks(n: int) -> void:
	for i: int in range(n): await physics_frame
func run() -> void:
	world=Node3D.new(); root.add_child(world)
	var ground := GrayboxGeometry.box(world,"Ground",Vector3(1500,1,1500),Vector3(0,-.5,0),Color.GRAY,true)
	for id: String in RallyContentCatalog.VEHICLES:
		for surface: int in range(3):
			ground.set_meta("surface_id",surface)
			for mode: String in ["coast","heavy","trail","heavy_unassisted","heavy_fast"]:
				var def := RallyContentCatalog.vehicle(id)
				var car := RallyVehicle.new()
				car.config=def.physics_config()
				car.config.corner_brake_balance=mode!="heavy_unassisted"
				car.drivetrain.config=def.drivetrain_config()
				world.add_child(car)
				car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,.8,0)))
				await ticks(120)
				var static_front := car.wheels[0].load+car.wheels[1].load
				var static_rear := car.wheels[2].load+car.wheels[3].load
				var entry_speed := 36.0 if mode=="heavy_fast" else 24.0
				car.linear_velocity=Vector3(0,0,-entry_speed)
				for wheel: RallyWheelState in car.wheels: wheel.omega=entry_speed/car.config.wheel_radius
				car.drivetrain.gear=3
				car.drivetrain.engine_omega=entry_speed/car.config.wheel_radius*car.drivetrain.ratio()
				var record := {"vehicle":id,"surface":surface,"mode":mode,"static_front":static_front,"static_rear":static_rear,"frames":[]}
				for frame: int in range(180):
					car.command.steer=.60 if mode=="heavy_fast" else .18
					car.command.brake=0 if mode=="coast" else (.95 if mode!="trail" else lerpf(.75,.15,float(frame)/180))
					await ticks(1)
					if frame%6: continue
					var local := car.basis.inverse()*car.linear_velocity
					var wheels: Array=[]
					for w: RallyWheelState in car.wheels:
						wheels.append({"load":w.load,"slip":w.slip,"angle_deg":rad_to_deg(w.slip_angle),"fx":w.longitudinal_force,"fy":w.lateral_force,"steer":w.steer})
					record.frames.append({"t":float(frame)/120,"speed":car.linear_velocity.length(),"yaw_deg_s":rad_to_deg(car.angular_velocity.y),"beta_deg":rad_to_deg(atan2(local.x,maxf(1,-local.z))),"wheels":wheels})
				samples.append(record)
				car.free();await process_frame
				print("AUDIT ",id," ",surface," ",mode)
	var file := FileAccess.open("res://docs/brushline/scene-refresh/braking-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t"))
	world.free();quit()

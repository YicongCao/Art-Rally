extends "res://tests/test_suite.gd"
func _run() -> void:
	assist_guards()
	if "--guards" in OS.get_cmdline_user_args():
		finish()
		return
	var world := Node3D.new()
	root.add_child(world)
	var reports: Array=[]
	var ids: Array=RallyContentCatalog.VEHICLES
	for surface: int in [1,2]:
		if "--gravel" in OS.get_cmdline_user_args() and surface!=1: continue
		var floor_root := Node3D.new()
		world.add_child(floor_root)
		var field := RallySurfaceField.new()
		field.base_id=surface
		floor_root.add_child(field)
		var grade := Basis(Vector3.RIGHT,atan(.10))
		var floor_body := GrayboxGeometry.box(floor_root,"Uphill",Vector3(160,1,2000),grade*Vector3(0,-.5,-650),Color.GRAY,true)
		floor_body.basis=grade
		field.attach(floor_body)
		for id: String in ids:
			if "--fwd" in OS.get_cmdline_user_args() and id!="F160": continue
			var definition := RallyContentCatalog.vehicle(id)
			var car := RallyVehicle.new()
			car.config=definition.physics_config()
			car.drivetrain.config=definition.drivetrain_config()
			car.transform=Transform3D(grade,grade*Vector3(0,.85,0))
			world.add_child(car)
			car.command.brake=1
			await ticks(240)
			car.command.brake=0
			car.command.throttle=1
			var limiter_seconds := 0.0
			var max_gear := 1
			var slip_sum := 0.0
			var duration := 20 if surface==1 else 40
			var speed_at_20 := 0.0
			for frame: int in range(duration*120):
				await ticks(1)
				if "--trace" in OS.get_cmdline_user_args() and frame%240==0: print("TRACE ",frame/120.0," kmh=",car.linear_velocity.length()*3.6," rpm=",car.drivetrain.rpm()," traction=",car.drivetrain.traction_scale," spin=",car.drivetrain.wheelspin," engine=",car.drivetrain.effective_throttle)
				max_gear=maxi(max_gear,car.drivetrain.gear)
				if frame==2399: speed_at_20=car.linear_velocity.length()*3.6
				if frame>duration*120-1200:
					slip_sum+=car.drivetrain.wheelspin/1199
					if car.drivetrain.gear==1 and car.drivetrain.rpm()>7200 and car.linear_velocity.length()<9: limiter_seconds+=1.0/120
			var report := {"vehicle":id,"surface":surface,"grade":.10,"duration":duration,"speed_at_20":speed_at_20,"power_ps":definition.power_ps,"speed_kmh":car.linear_velocity.length()*3.6,"gear":car.drivetrain.gear,"max_gear":max_gear,"late_slip":slip_sum,"stuck_limiter_seconds":limiter_seconds}
			reports.append(report)
			print("LOOSE CLIMB: ",JSON.stringify(report))
			if surface==1:
				check(report.speed_kmh>45 and max_gear>=2,id+" accelerates uphill and upshifts on gravel")
			else:
				# Mud on a 10% incline can remain traction-limited in first;
				# require continued real acceleration, not a cosmetic gear change.
				check((speed_at_20>30 and report.speed_kmh>speed_at_20+5) or report.speed_kmh>90,id+" keeps accelerating on the muddy incline")
			check(limiter_seconds<1 and slip_sum<.65,id+" avoids sustained first-gear limiter wheelspin")
			car.free()
			await ticks(2)
		floor_root.free()
		await ticks(2)
	world.free()
	var file := FileAccess.open("res://docs/validation/loose-climb-after.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	await process_frame
	finish()


func assist_guards() -> void:
	var drive := RallyDrivetrain.new()
	drive.config=RallyContentCatalog.vehicle("F160").drivetrain_config()
	var command := DriverCommand.new()
	command.throttle=1
	var wheels: Array[RallyWheelState]=[]
	for i: int in range(4):
		var wheel := RallyWheelState.new()
		wheel.grounded=true
		wheel.load=2500
		wheel.surface=RallySurfaceSample.from_profile(load("res://resources/surfaces/gravel.tres"))
		wheel.longitudinal_speed=6
		wheel.omega=100
		wheels.append(wheel)
	drive.reset()
	drive.engine_omega=7400*TAU/60
	drive.begin_tick(command,6,.34,wheels)
	check(drive.gear==1,"Assistance cannot shift up on inflated RPM alone")
	for i: int in range(40): drive._update_traction(command,wheels,1.0/120)
	check(drive.traction_scale<.5,"Sustained driven-wheel slip progressively reduces engine input")
	for wheel: RallyWheelState in wheels: wheel.surface=RallySurfaceSample.from_profile(load("res://resources/surfaces/asphalt.tres"))
	drive.begin_tick(command,6,.34,wheels)
	for i: int in range(120): drive._update_traction(command,wheels,1.0/120)
	check(is_equal_approx(drive.traction_scale,1),"Returning to asphalt smoothly restores full driver input")
	for i: int in range(2):
		wheels[i].surface=RallySurfaceSample.from_profile(load("res://resources/surfaces/gravel.tres"))
		wheels[i].grounded=false
	drive.begin_tick(command,6,.34,wheels)
	check(not drive.loose_contact and drive.gear==1,"Airborne powered axle cannot activate assistance or shift")
	for i: int in range(2): wheels[i].grounded=true
	drive.traction_scale=.1
	drive.engine_omega=1800*TAU/60
	drive.begin_tick(command,1,.34,wheels)
	drive._update_traction(command,wheels,.1)
	check(drive.traction_scale>.1,"Low-RPM launch recovers torque instead of disengaging the clutch")
	drive.automatic=false
	drive.gear=3
	drive.begin_tick(command,6,.34,wheels)
	check(drive.gear==3,"Loose-ground assistance preserves manual gear selection")

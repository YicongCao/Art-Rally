extends "res://tests/test_suite.gd"


func pedal(throttle: float,brake: float) -> DriverCommand:
	var command := DriverCommand.new()
	command.throttle = throttle
	command.brake = brake
	return command


func _run() -> void:
	var config := RallyDrivetrainConfig.new()
	var omega := PackedFloat64Array([10,20,30,60])
	for layout: String in ["FWD","AWD","RWD"]:
		config.drive_layout = layout
		var torque := RallyDrivetrain.distribute(800,omega,false,config)
		check(is_equal_approx(torque[0]+torque[1]+torque[2]+torque[3],800),layout+" preserves total drive torque")
		if layout=="FWD": check(torque[2]==0 and torque[3]==0,"FWD rear wheels receive no drive or limited-slip coupling")
		elif layout=="RWD": check(torque[0]==0 and torque[1]==0,"RWD front wheels receive no drive or limited-slip coupling")
	var wheels: Array[RallyWheelState] = []
	for i: int in range(4):
		var wheel := RallyWheelState.new()
		wheel.omega = 10 if i<2 else 80
		wheels.append(wheel)
	for layout: String in ["FWD","RWD"]:
		var shaft := RallyDrivetrain.new()
		shaft.config = shaft.config.duplicate()
		shaft.config.drive_layout = layout
		shaft.engine_omega = 300
		shaft.step(pedal(0,0),wheels,1.0/480)
		check(shaft.clutch_torque>0 if layout=="FWD" else shaft.clutch_torque<0,layout+" engine couples only to driven axle speed")
		if layout=="RWD":
			var handbrake := pedal(1,0)
			handbrake.handbrake = 1
			shaft.step(handbrake,wheels,1.0/480)
			check(shaft.clutch==0,"RWD handbrake releases clutch instead of driving locked rear wheels")
	var assist := RallyReverseAssist.new()
	var drive := RallyDrivetrain.new()
	for i: int in range(400): assist.apply(pedal(0,1),pedal(0,1),drive,5,true,1.0/120)
	check(assist.held_seconds==0 and drive.gear==1,"Braking while moving does not advance reverse countdown")
	for i: int in range(119): assist.apply(pedal(0,1),pedal(0,1),drive,0,true,1.0/120)
	check(drive.gear==1 and assist.remaining()>0,"Stationary reverse hold lasts full one second")
	assist.apply(pedal(0,1),pedal(0,0),drive,0,true,1.0/120)
	check(assist.held_seconds==0,"Raw pedal release cancels hold despite filtered brake residue")
	for i: int in range(120): assist.apply(pedal(0,1),pedal(0,1),drive,0,true,1.0/120)
	check(drive.gear==-1 and drive.shift_remaining>0,"Completed one-second hold requests reverse through gearbox")
	drive.shift_remaining = 0
	var output := assist.apply(pedal(0,1),pedal(0,1),drive,0,true,0.3)
	check(output.throttle==1 and output.brake==0,"Reverse maps brake pedal to reverse acceleration")
	output = assist.apply(pedal(1,0),pedal(1,0),drive,3,true,0.01)
	check(drive.gear==-1 and output.throttle==0 and output.brake>0 and assist.returning_forward,"Forward pedal first brakes a moving reverse car")
	assist.apply(pedal(1,0),pedal(1,0),drive,0.1,true,0.01)
	check(drive.gear==1,"Forward pedal selects first gear after stopping")
	output = assist.apply(pedal(0,1),pedal(0,1),drive,0,true,0.01)
	check(output.brake==1 and output.throttle==0,"Brake pedal resumes its braking role in forward gear")
	drive.reset()
	assist.reset()
	for i: int in range(400): assist.apply(pedal(0,1),pedal(0,1),drive,0,false,1.0/120)
	check(drive.gear==1 and assist.remaining()==0,"Airborne car cannot arm automatic reverse")
	assist.apply(pedal(0,1),pedal(0,1),drive,0,true,0.5)
	assist.reset()
	check(assist.remaining()==0,"Pause/recovery can clear countdown state")
	drive.shift_remaining = 0.1
	assist.apply(pedal(0,1),pedal(0,1),drive,0,true,0.5)
	check(assist.held_seconds==0.5,"Automatic downshift interruption does not restart the stationary hold timer")
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene._open_vehicle_selection()
	check(paused and scene.selecting_vehicle and scene.controls.blocked,"Pre-race selection freezes session and driver input")
	scene._toggle_pause()
	scene._restart()
	check(paused and scene.selecting_vehicle,"Pause/restart shortcuts cannot bypass initial vehicle choice")
	for layout: String in ["FWD","AWD","RWD"]:
		scene._confirm_vehicle(layout)
		await ticks(360)
		check(scene.vehicle.drivetrain.config.drive_layout==layout and not paused,layout+" choice starts a fresh drive session")
		scene.controls.keys[KEY_W] = true
		await ticks(360)
		check(scene.vehicle.linear_velocity.length()>2,layout+" accelerates through actual tire forces")
		scene._open_vehicle_selection(true)
	check(load("res://resources/vehicles/drivetrain.tres").drive_layout=="AWD","Vehicle choice does not mutate shared AWD resource")
	scene._cancel_vehicle_selection()
	check(not scene.selecting_vehicle and paused and scene.vehicle.drivetrain.config.drive_layout=="RWD","Cancelling reselection preserves previous layout and paused session")
	scene._restart()
	await ticks(360)
	# Leave room behind the car; the start-line apron intentionally has an out-of-bounds limit.
	scene.vehicle.request_reset(scene.generator.route.pose_at(300))
	await ticks(240)
	scene.controls.keys[KEY_S] = true
	await ticks(400)
	check(scene.vehicle.drivetrain.gear==-1 and scene.vehicle.command.throttle>0,"Real S input performs hold-to-reverse without manual shifting")
	await ticks(180)
	var forward: Vector3 = -scene.vehicle.basis.z
	check(scene.vehicle.linear_velocity.dot(forward)<-0.5,"Reverse assist actually drives the vehicle backward")
	scene.controls.keys[KEY_S] = false
	scene.controls.keys[KEY_W] = true
	await ticks(480)
	print("DIRECTION METRIC: gear=",scene.vehicle.drivetrain.gear," velocity=",scene.vehicle.linear_velocity," resets=",scene.session.reset_count," phase=",scene.session.phase," blocked=",scene.controls.blocked)
	check(scene.vehicle.drivetrain.gear>0 and scene.vehicle.linear_velocity.dot(-scene.vehicle.basis.z)>0.5,"Forward input safely stops reverse motion then drives forward")
	scene._safety_pause()
	check(scene.reverse_assist.remaining()==0,"Focus-loss pause cancels assisted direction timer")
	scene.queue_free()
	paused = false
	await process_frame
	finish()

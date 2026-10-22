extends SceneTree
# Drive off the road on the real stage and measure whether the car can stop.
# For each station, the car is placed beside the road at a lateral offset with
# 50 km/h aimed 30 deg away from the road, then brakes fully.
#   godot --headless --path . --fixed-fps 120 --script res://scripts/dev/offroad_stage_audit.gd -- --stage=redrock_canyon
func _initialize() -> void: run.call_deferred()
func ticks(n: int) -> void:
	for i: int in range(n): await physics_frame
func run() -> void:
	var stage_id := "redrock_canyon"
	var vehicle_id := "R200"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="): stage_id=argument.trim_prefix("--stage=")
		if argument.begins_with("--car="): vehicle_id=argument.trim_prefix("--car=")
	# Stage geometry and scenery only: real road, terrain and obstacle collision,
	# without the stage driver loop overriding the test's pedal commands.
	var generator := RallyStageGenerator.new()
	generator.definition=RallyContentCatalog.stage(stage_id)
	root.add_child(generator)
	var land := RallyStageScenery.new()
	root.add_child(land)
	land.build(generator)
	var route: RallyStageRoute=generator.route
	var def := RallyContentCatalog.vehicle(vehicle_id)
	var car := RallyVehicle.new()
	car.config=def.physics_config()
	car.drivetrain.config=def.drivetrain_config()
	root.add_child(car)
	await ticks(2)
	var speed_kmh := 90.0
	var mode := "brake"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--speed="): speed_kmh=float(argument.trim_prefix("--speed="))
		if argument.begins_with("--mode="): mode=argument.trim_prefix("--mode=")
	var stats := []
	for i: int in range(12):
		var s := route.length*(.06+.075*i)
		if absf(route.definition.mountain_side_at(s))>.01: continue
		for side: float in [-1,1]:
			var pose := route.pose_at(s,0)
			var right: Vector3=route.rights[route.index_at(s)]*side
			# Leave the road edge at speed, 20 deg outward, as a missed corner would.
			var start := land.ground_at(s,side*(route.width_at(s)*.5-.6))
			var heading := (-pose.basis.z).rotated(Vector3.UP,-side*deg_to_rad(20))
			heading.y=0
			car.request_reset(Transform3D(Basis.looking_at(heading.normalized(),Vector3.UP),start+Vector3.UP*.8))
			await ticks(60)
			var speed := speed_kmh/3.6
			car.linear_velocity=heading.normalized()*speed
			for wheel: RallyWheelState in car.wheels: wheel.omega=speed/car.config.wheel_radius
			var travelled := 0.0
			var previous := car.global_position
			var stopped := false
			var contact_frames := 0
			var frames := 0
			var surfaces := {}
			var max_slope := 0.0
			var start_lat := route.width_at(s)*.5
			var max_out := 0.0
			for frame: int in range(120*8):
				car.command.throttle=0
				car.command.brake=1.0 if mode in ["brake","recover"] else 0.0
				# Recovery: steer back toward the road while braking.
				car.command.steer=(-side*.6) if mode=="recover" else 0.0
				await ticks(1)
				frames+=1
				travelled+=previous.distance_to(car.global_position)
				previous=car.global_position
				var touching := 0
				for wheel: RallyWheelState in car.wheels:
					if wheel.grounded:
						touching+=1
						surfaces[wheel.surface.surface_id]=int(surfaces.get(wheel.surface.surface_id,0))+1
				if touching>=3: contact_frames+=1
				max_slope=maxf(max_slope,land.terrain_slope_at(car.global_position))
				var here := land.nearest(car.global_position)
				max_out=maxf(max_out,absf(float(here.lateral))-route.width_at(float(here.s))*.5)
				if car.linear_velocity.length()<.6:
					stopped=true
					break
			var near:=land.nearest(car.global_position)
			stats.append({"s":int(s),"side":side,"stopped":stopped,"travel_m":snappedf(travelled,.1),"grounded":snappedf(float(contact_frames)/frames,.01),"end_lat":snappedf(float(near.lateral),.1),"end_speed_kmh":snappedf(car.linear_velocity.length()*3.6,.1),"surfaces":surfaces,"max_slope":snappedf(max_slope,.01),"outward_m":snappedf(absf(float(near.lateral))-start_lat,.1),"max_out":snappedf(max_out,.1),"reset":max_out>18-route.width_at(s)*.5,"fell":car.global_position.y<land.rendered_height_at(car.global_position.x,car.global_position.z)-1.5})
	var stopped_count := 0
	var resets := 0
	var travel := []
	var outs := []
	var airborne := 0.0
	var fell := 0
	for x: Dictionary in stats:
		if x.stopped: stopped_count+=1
		if x.reset: resets+=1
		travel.append(x.travel_m)
		outs.append(x.max_out)
		airborne+=1-float(x.grounded)
		if x.fell: fell+=1
	travel.sort()
	outs.sort()
	print("OFFROAD_STAGE ",JSON.stringify({"stage":stage_id,"car":vehicle_id,"mode":mode,"speed":speed_kmh,"trials":stats.size(),"stopped":stopped_count,"would_reset":resets,"median_travel":travel[travel.size()/2],"max_travel":travel[-1],"median_out":outs[outs.size()/2],"max_out":outs[-1],"airborne":snappedf(airborne/stats.size(),.01),"fell_through":fell}))
	for x: Dictionary in stats: print("TRIAL ",JSON.stringify(x))
	quit()

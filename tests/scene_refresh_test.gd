extends "res://tests/test_suite.gd"
func _run() -> void:
	var advice := RallyRecoveryAdvice.new()
	for i: int in range(600): advice.update(1.0/120,0,1,1,0,0,true)
	check(not advice.visible,"Intentional idle does not demand recovery")
	for i: int in range(510): advice.update(1.0/120,0,1,1,1,0,true)
	check(advice.visible,"Persistent blocked throttle offers recovery")
	check(not advice.update(.1,8,1,1,1,0,true),"Motion clears recovery advice")
	for i: int in range(270): advice.update(1.0/120,.1,-1,1,0,0,true)
	check(advice.visible,"Overturned car gets a recover hint")
	advice.reset()
	for i: int in range(630): advice.update(1.0/120,0,1,-1,0,0,true)
	check(advice.visible and not advice.update(.1,0,-1,-1,1,0,false),"Wrong-way hint clears in non-driving states")
	var generator := RallyStageGenerator.new()
	generator.definition=RallyContentCatalog.stage("misty_highlands")
	root.add_child(generator)
	var land := RallyStageScenery.new()
	root.add_child(land);land.build(generator)
	await ticks(3)
	check(generator.definition.river_crossings.is_empty() and land.river_frames.is_empty(),"Highland has no cross-road rivers or bridge profile")
	check(generator.definition.stage_version=="9","Changed highland road uses new score compatibility version")
	var space := land.get_world_3d().direct_space_state
	var holes := 0
	var road_intrusions := 0
	var checks_count := 0
	for s: int in range(90,2800,12):
		var side := generator.definition.mountain_side_at(s)
		var pose := generator.route.pose_at(s,0)
		var road_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pose.origin+Vector3.UP*6,pose.origin-Vector3.UP*2,1))
		if road_hit.is_empty() or road_hit.position.y>pose.origin.y+.30: road_intrusions+=1
		if absf(side)<.2: continue
		for gap: float in [.1,.5,1,2,3,4,6,9]:
			var p := pose.origin+pose.basis.x*signf(side)*(generator.route.width_at(s)*.5+gap)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*65,p-Vector3.UP*6,1))
			checks_count+=1
			if hit.is_empty() or hit.position.y<pose.origin.y-3.0: holes+=1
	print("MOUNTAIN BANK RAYS: ",checks_count," holes: ",holes," road intrusions: ",road_intrusions)
	check(holes==0,"Mountain-side tire support has no shoulder-to-slope holes")
	check(road_intrusions==0,"Terrain collision never rises through driving surface")
	for id: String in RallyContentCatalog.VEHICLES:
		var definition := RallyContentCatalog.vehicle(id)
		var car := RallyVehicle.new()
		car.config=definition.physics_config()
		car.drivetrain.config=definition.drivetrain_config()
		root.add_child(car)
		for station: float in [450,900,2490]:
			var pose := generator.route.pose_at(station,0)
			pose.origin+=pose.basis.x*signf(generator.definition.mountain_side_at(station))*(generator.route.width_at(station)*.5+2)
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(pose.origin+Vector3.UP*50,pose.origin-Vector3.UP*5,1))
			pose.origin.y=ground.position.y+.8
			car.request_reset(pose)
			for frame: int in range(360):
				car.command.brake=1
				await ticks(1)
			check(car.position.y>generator.route.position_at(station).y-3 and car.linear_velocity.y> -10,id+" physically stays supported on the mountain bank at %d m"%station)
		car.free()
	var sky := RallySkyLife.new();root.add_child(sky);sky.build(land)
	check(sky.flocks.size()==3 and sky.birds.size()==18,"Three spaced flocks have six authored birds each")
	check(sky.birds[0].wings[0]!=null and sky.birds[0].wings[1]!=null,"Blender wing mounts survive export")
	for flock: Dictionary in sky.flocks:
		var score := sky._visibility_score(land,flock.station,PackedVector3Array([flock.from,flock.to]))
		check(score>=2,"Highland flyby at %d m has at least two unoccluded viewing samples (%d/6)"%[flock.station,score])
	sky.advance(.1,0)
	check(not sky.birds[0].node.visible,"Birds wait for approach rather than expiring before arrival")
	sky.advance(2,sky.flocks[0].station-50)
	var before: Vector3=sky.birds[0].node.position
	sky.advance(1,sky.flocks[0].station)
	check(sky.birds[0].node.visible and before.distance_to(sky.birds[0].node.position)>2,"Visible flock advances through the flyby")
	for i: int in range(28):sky.advance(1,sky.flocks[0].station)
	check(sky.flocks[0].done and not sky.birds[0].node.visible,"Flyby completes after its fade-out")
	sky.advance(.1,0)
	check(not sky.flocks[0].done,"Restart rearms the sky events")
	var road := generator.road_visuals[0].material_override as ShaderMaterial
	check(road.get_shader_parameter("wear_atlas")!=null and road.get_shader_parameter("wear_strength")>.4,"Generated wear atlas is bound and enabled on road material")
	check(land.dressing.get_node("StageTerrain").material_override.get_shader_parameter("rock_albedo")!=null,"Painterly rock texture reaches actual terrain shader")
	sky.free();land.free();generator.free();await process_frame
	finish()

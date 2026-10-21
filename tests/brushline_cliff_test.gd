extends "res://tests/test_suite.gd"
func _run() -> void:
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://cliff-validation-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.chosen_stage="misty_highlands"
	app.practice=true
	await app.start_race()
	var race: Node3D=app.race
	race.set_process(false)
	race._set_autopilot_mode_name("off")
	await ticks(2)
	var space := race.get_world_3d().direct_space_state
	for s: float in [450,900,1480,1930,2490]:
		var pose: Transform3D=race.generator.route.pose_at(s,0)
		var ray := PhysicsRayQueryParameters3D.create(pose.origin+Vector3.UP*3,pose.origin-Vector3.UP*3,1)
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty() and absf(hit.position.y-pose.origin.y)<.7,"Road stays supported at %d m"%s)
		var cliff: Vector3=pose.origin-pose.basis.x*signf(race.challenge.stage.mountain_side_at(s))*14
		ray.from=cliff+Vector3.UP
		ray.to=cliff-Vector3.UP*6
		check(space.intersect_ray(ray).is_empty(),"Cliff has no invisible road-height platform at %d m"%s)
	var drop: Transform3D=race.generator.route.pose_at(900,0)
	drop.origin-=drop.basis.x*signf(race.challenge.stage.mountain_side_at(900))*14
	drop.origin.y+=1
	race.session.projection_hint=race.generator.route.index_at(900)
	race.session.progress=900
	race.session.phase=RallyStageSession.Phase.RUNNING
	race.vehicle.request_reset(drop)
	await ticks(10)
	var initial_y: float=race.vehicle.global_position.y
	var resets: int=race.session.reset_count
	await ticks(90)
	check(race.vehicle.global_position.y<initial_y-1.8,"A car beyond the cliff actually falls under gravity")
	check(race.session.reset_count==resets,"The fall is visible before one eventual recovery")
	await ticks(360)
	check(race.session.reset_count==resets+1,"Cliff recovery applies exactly one reset after the visible fall")
	race.session.phase=RallyStageSession.Phase.RUNNING
	# All body envelopes and tiers, including stationary, reverse and close shoulder cases.
	race.vehicle.freeze=true
	for car_id: String in RallyContentCatalog.VEHICLES:
		for tier: int in range(3):
			race.vehicle.config=RallyContentCatalog.challenge("misty_highlands",car_id,tier).vehicle.physics_config()
			var safe := true
			for speed: float in [0,-8,25]:
				race.rockfall.reset()
				race.rockfall.closest_clearance=INF
				var pose: Transform3D=race.generator.route.pose_at(450,0)
				race.vehicle.global_transform=pose
				race.vehicle.global_position+=pose.basis.x*float(race.rockfall.events[0].side)*4.5
				race.vehicle.linear_velocity=-pose.basis.z*speed
				race.session.progress=450
				for i: int in range(600): race.rockfall.advance(1.0/60)
				if race.rockfall.closest_clearance<1.49: safe=false
				if speed>0 and race.rockfall.closest_clearance>3.0: safe=false
				if not race.rockfall.events[0].items[0].visible: safe=false
			check(safe,car_id+" tier %d stays visibly separated by 1.5 m at every speed"%tier)
	await app.leave_race()
	app.free()
	await process_frame
	finish()

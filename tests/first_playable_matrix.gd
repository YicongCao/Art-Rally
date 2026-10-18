extends "res://tests/test_suite.gd"
func _run() -> void:
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://matrix-test/profile.json"
	app.profile.data = RallyProfileStore.fresh()
	var reports: Array = []
	for stage_id: String in RallyContentCatalog.STAGES:
		for vehicle_id: String in RallyContentCatalog.VEHICLES:
			app.chosen_stage = stage_id
			app.chosen_vehicle = vehicle_id
			await app.start_race()
			var scene: Node3D = app.race
			scene.set_process(false)
			scene._set_autopilot_mode_name("vgamepad")
			var max_lateral := 0.0
			var costs: Array[int] = []
			var last_progress := 0.0
			var stalled := 0
			for i: int in range(120*650):
				await ticks(1)
				max_lateral = maxf(max_lateral,absf(float(scene.session.projection.get("lateral",0))))
				costs.append(scene.vehicle.physics_usec)
				if i%120==0:
					if scene.session.progress>last_progress+.2:
						last_progress = scene.session.progress
						stalled = 0
					else: stalled+=1
				if scene.session.phase==RallyStageSession.Phase.FINISHED or stalled>30 or scene.session.reset_count>0: break
			costs.sort()
			var report := {"stage":stage_id,"vehicle":vehicle_id,"finished":scene.session.phase==RallyStageSession.Phase.FINISHED,"elapsed":scene.session.elapsed,"recoveries":scene.session.reset_count,"progress":scene.session.progress,"max_lateral":max_lateral,"physics_p95_ms":costs[int(costs.size()*.95)]/1000.0,"splits":scene.session.split_times}
			reports.append(report)
			print("CHALLENGE DRIVE: ",JSON.stringify(report))
			check(report.finished,stage_id+" / "+vehicle_id+" completes every checkpoint")
			check(report.recoveries==0,stage_id+" / "+vehicle_id+" needs no recovery")
			check(app.profile.data.challenges.is_empty(),"Autopilot never writes player records")
			app.leave_race()
			await process_frame
	var file := FileAccess.open("res://logs/first_playable_matrix.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	app.queue_free()
	await process_frame
	finish()

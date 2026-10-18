extends "res://tests/test_suite.gd"
func _run() -> void:
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://matrix-test-%d/profile.json"%OS.get_process_id()
	app.profile.data = RallyProfileStore.fresh()
	var reports: Array = []
	app.profile.data.unlocked_power_tier = 2
	var tiers: Array = [0,1,2]
	var suffix := ""
	var input_mode := "vgamepad"
	var stage_filter := ""
	var vehicle_filter := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--input="): input_mode = argument.trim_prefix("--input=")
		if argument.begins_with("--stage="): stage_filter = argument.trim_prefix("--stage=")
		if argument.begins_with("--vehicle="): vehicle_filter = argument.trim_prefix("--vehicle=")
		if argument.begins_with("--tier="):
			var selected := int(argument.trim_prefix("--tier="))
			assert(selected>=0 and selected<=2)
			tiers = [selected]
			suffix = "_tier_%d"%selected
	if input_mode!="vgamepad": suffix += "_"+input_mode
	for tier: int in tiers:
		app.chosen_power_tier = tier
		for stage_id: String in RallyContentCatalog.STAGES:
			if not stage_filter.is_empty() and stage_id!=stage_filter: continue
			for vehicle_id: String in RallyContentCatalog.VEHICLES:
				if not vehicle_filter.is_empty() and vehicle_id!=vehicle_filter: continue
				app.chosen_stage = stage_id
				app.chosen_vehicle = vehicle_id
				await app.start_race()
				var scene: Node3D = app.race
				scene.set_process(false)
				scene._set_autopilot_mode_name(input_mode)
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
				var report := {"stage":stage_id,"vehicle":vehicle_id,"power_tier":tier,"input":input_mode,"finished":scene.session.phase==RallyStageSession.Phase.FINISHED,"elapsed":scene.session.elapsed,"recoveries":scene.session.reset_count,"progress":scene.session.progress,"max_lateral":max_lateral,"physics_p95_ms":costs[int(costs.size()*.95)]/1000.0,"splits":scene.session.split_times}
				reports.append(report)
				if "--save-replays" in OS.get_cmdline_user_args() and tier==0 and vehicle_id=="A240":
					var saved := FileAccess.open("res://logs/route-replay-"+stage_id+".json",FileAccess.WRITE)
					saved.store_string(JSON.stringify({"recording":scene.trajectory.payload(scene.challenge.key(),scene.session.total_time()),"result":report}))
				print("CHALLENGE DRIVE: ",JSON.stringify(report))
				check(report.finished,stage_id+" / "+vehicle_id+" completes every checkpoint")
				check(report.recoveries==0,stage_id+" / "+vehicle_id+" needs no recovery")
				check(app.profile.data.challenges.is_empty(),"Autopilot never writes player records")
				app.leave_race()
				await process_frame
	var file := FileAccess.open("res://logs/first_playable_matrix"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	app.queue_free()
	await process_frame
	finish()

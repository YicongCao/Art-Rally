extends "res://tests/test_suite.gd"
func _run() -> void:
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://brushline-demo-test-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="DEMO"
	app.chosen_stage="sunset_ridge"
	app.chosen_vehicle="R200"
	app.practice=true
	await app.start_race()
	var demo := RallyBenchmarkDemo.new()
	app.race.add_child(demo)
	demo.begin(app.race)
	var baseline: Dictionary=app.profile.data.duplicate(true)
	var shots: Array[int]=[]
	while demo.elapsed<120:
		await process_frame
		paused=false
		if app.race.controls.blocked: app.race.controls.resume()
		if DisplayServer.get_name()!="headless":
			var section := int(demo.elapsed/40)
			if not section in shots and fmod(demo.elapsed,40)>12:
				shots.append(section)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg("res://docs/brushline/demo-%d.jpg"%section,.92)
	var report := demo.report()
	FileAccess.open("res://logs/brushline-demo.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BRUSHLINE DEMO: ",report.duplicate().merged({"samples":"see JSON"},true))
	check(report.peak_sideslip_deg>8 and report.peak_sideslip_deg<65,"Real oversteer remains controlled")
	check(report.countersteered and report.recovered,"Measured opposite lock recovers side slip")
	check(report.resets==0,"The demonstration does not need recovery")
	check(app.profile.data.challenges==baseline.challenges and app.profile.data.unlocked_stages==baseline.unlocked_stages,"Demo leaves records, medals and unlocks untouched")
	check(not app.race.broadcast.photos_enabled,"Demo never writes player photographs")
	await app.leave_race()
	app.free()
	await process_frame
	finish()

extends "res://tests/test_suite.gd"
func _run() -> void:
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://lifecycle-test/profile.json"
	app.profile.data = RallyProfileStore.fresh()
	var reports: Array = []
	for i: int in range(10):
		app.chosen_stage = RallyContentCatalog.STAGES[i%3]
		app.chosen_vehicle = RallyContentCatalog.VEHICLES[i%3]
		await app.start_race()
		app.leave_race()
		for frame: int in range(3): await process_frame
		reports.append({"cycle":i+1,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"memory":OS.get_static_memory_usage()})
		print("SCENE CYCLE: ",reports[-1])
	check(reports[-1].nodes<=reports[0].nodes+2,"Ten scene switches retain no scene nodes")
	check(reports[-1].orphans<=reports[0].orphans,"Ten scene switches retain no orphan nodes")
	check(reports[-1].resources<=reports[2].resources+5,"Resources remain bounded after all three themes warm up")
	var file := FileAccess.open("res://logs/first_playable_lifecycle.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	app.queue_free()
	await process_frame
	finish()

extends "res://tests/test_suite.gd"

func _run() -> void:
	check(RallyPlateText.font().has_char("R".unicode_at(0)) and RallyPlateText.font().has_char("沪".unicode_at(0)),"Stylized plate font keeps Chinese fallback")
	var themes: Array = []
	for key: String in ["menu","autumn","coast","highland"]:
		var music := RallyAudioDirector.music_asset(key)
		check(music.get_length()>25 and music.loop_end==roundi(music.get_length()*music.mix_rate),key+" contains a full offline music loop")
		themes.append(hash(music.data))
	check(themes.size()==4 and themes[0]!=themes[1] and themes[1]!=themes[2] and themes[2]!=themes[3],"Four scenes use distinct compositions")
	for id: String in RallyContentCatalog.STAGES:
		var stage := RallyContentCatalog.stage(id)
		var weights := stage.surface_proportions()
		var kinds := int(weights.x>.001)+int(weights.y>.001)+int(weights.z>.001)
		check(kinds>=2 and is_equal_approx(weights.x+weights.y+weights.z,1),id+" has multiple surfaces and normalized ratios")
		check(stage.river_crossings.size()>=1 and stage.river_crossings.size()<=3,id+" has 1–3 river crossings")
		for crossing: Vector3 in stage.river_crossings:
			check(stage.width_at(crossing.x)<stage.road_width-.4,id+" bridge narrows the driving corridor")
		for section: Vector3 in stage.surface_sections:
			var a := stage.surface_weights(section.x-.01)
			var b := stage.surface_weights(section.x+.01)
			check(a.distance_to(b)<.01,id+" surface transition has continuous grip weights")
		var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
		app.profile.path = "user://expansion-test/profile.json"
		root.add_child(app)
		app.profile.data = RallyProfileStore.fresh()
		app.chosen_stage = id
		await app.start_race()
		check(app.race.presentation.sky_life.balloons.size() in range(7,16),id+" has a visible authored balloon group")
		check((app.race.presentation.sky_life.birds.is_empty() if id=="sunset_ridge" else app.race.presentation.sky_life.birds.size() in range(15,19)),id+" distant seabird population is correct")
		for crossing: Vector3 in stage.river_crossings:
			check(app.race.presentation.scenery.dressing.has_node("RiverBridge%d"%crossing.x),id+" river and bridge geometry loads")
		if id=="sunlit_cape": check(app.race.presentation.scenery.sailboats.size()==4,"Coastal sailing boats are present and animated")
		var helicopter: RallyBroadcastHelicopter = app.race.broadcast
		helicopter.photos_enabled = false
		app.race.session.phase = RallyStageSession.Phase.RUNNING
		for fraction: float in RallyBroadcastHelicopter.FRACTIONS:
			app.race.session.progress = stage.target_length*fraction+1
			for i: int in range(48): helicopter.advance(1)
		check(helicopter.next_pass==4 and helicopter.shot_count==4,id+" helicopter makes four photographic passes")
		await app.leave_race()
		app.queue_free()
		await process_frame
	finish()

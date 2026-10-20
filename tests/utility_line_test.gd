extends "res://tests/test_suite.gd"

func _run() -> void:
	for stage_id: String in RallyContentCatalog.STAGES:
		var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
		app.profile.path="user://utility-test-%s/profile.json"%Time.get_ticks_usec()
		root.add_child(app)
		app.chosen_stage=stage_id
		await app.start_race()
		var land: RallyStageScenery=app.race.presentation.scenery
		var line: RallyUtilityLine=land.utility_line
		check(line.poles.size()>45 and line.spans.size()==(line.poles.size()-1)*3,stage_id+" has one continuous three-wire route")
		var road_clear := true
		var grounded := true
		var wire_clear := true
		var max_height := 0.0
		for pole: Dictionary in line.poles:
			var near:=land.nearest(pole.base)
			road_clear=road_clear and near.distance>land.route.width_at(near.s)*.5+14
			grounded=grounded and absf(pole.base.y-land.rendered_height_at(pole.base.x,pole.base.z))<.01
			max_height=maxf(max_height,pole.height)
		for span: PackedVector3Array in line.spans:
			for point: Vector3 in span:
				wire_clear=wire_clear and point.y-land.rendered_height_at(point.x,point.z)>3.5
		check(road_clear,stage_id+" supports stay outside recovery corridor")
		check(grounded,stage_id+" supports sit on rendered terrain")
		check(max_height<18,stage_id+" wooden poles remain plausible height")
		check(wire_clear,stage_id+" sagging wires stay above terrain")
		print("UTILITY LINE ",stage_id," poles=",line.poles.size()," max_height=",max_height)
		await app.leave_race()
		app.free()
		await process_frame
	finish()

extends "res://tests/test_suite.gd"

func _run() -> void:
	for id: String in RallyContentCatalog.STAGES:
		var definition := RallyContentCatalog.stage(id)
		var route := RallyStageRoute.new()
		route.build(definition)
		check(route.validate().is_empty(),id+" has no crossing, unsafe grade or discontinuous frames")
		check(definition.stage_version=="6",id+" isolates old scores and ghosts after geometry changes")
		var min_width := 100.0
		var max_width := 0.0
		var largest_step := 0.0
		var hairpin_groups := 0
		var last_hairpin := -1000.0
		var direction_ok := true
		for i: int in range(1,route.points.size()-1):
			var s := route.distances[i]
			min_width = minf(min_width,route.width_at(s))
			max_width = maxf(max_width,route.width_at(s))
			largest_step = maxf(largest_step,absf(route.width_at(s)-route.width_at(s-route.spacing)))
			var bridge_approach := false
			for river: Vector3 in definition.river_crossings:
				if absf(s-river.x)<river.y*.5+20: bridge_approach=true
			if id=="sunlit_cape" and not bridge_approach: direction_ok = direction_ok and route.points[i].y<route.points[i-1].y
			if id=="misty_highlands" and not bridge_approach: direction_ok = direction_ok and route.points[i].y>route.points[i-1].y
			if i>15 and i<route.points.size()-15:
				var angle := absf(route.tangents[i-15].signed_angle_to(route.tangents[i+15],Vector3.UP))
				if angle>1.3 and s-last_hairpin>150:
					hairpin_groups+=1
					last_hairpin=s
		check(direction_ok,id+" follows its authored climb/descent")
		check(min_width>=RallyContentCatalog.vehicle("A240").body_size.x+2.0 and max_width-min_width>1.6 and largest_step<.25,id+" width changes are visible and continuous")
		check(hairpin_groups>=2,id+" contains several distinct switchbacks")
		for note: Dictionary in definition.hazard_notes:
			if note.code=="CAUTION_NARROW": check(route.width_at(note.s)<definition.road_width-.5,id+" caution call corresponds to an actual constriction")
			if note.code=="CUT": check(route.width_at(note.s)>definition.road_width+.7,id+" cut call has a widened driving corridor")
		if id=="sunset_ridge":
			check(definition.crests.size()==5 and definition.rolling_amplitude>1,"Forest has five authored jumps and rolling connectors")
		var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
		root.add_child(app)
		app.profile.path = "user://route-revision-test/profile.json"
		app.profile.data = RallyProfileStore.fresh()
		app.chosen_stage = id
		await app.start_race()
		var land: RallyStageScenery = app.race.presentation.scenery
		check(land.dressing.has_node("MedicalAndMarshals"),id+" has medical support and marshals")
		await ticks(2)
		var corridor_clear := true
		var space: PhysicsDirectSpaceState3D = app.race.vehicle.get_world_3d().direct_space_state
		for station: int in range(5,int(route.length)-5,3):
			for offset: float in [-1.1,0,1.1]:
				var at := route.position_at(station)+route.rights[route.index_at(station)]*offset
				var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.7,at+Vector3.UP*.15,4))
				if not hit.is_empty(): corridor_clear=false
		check(corridor_clear,id+" scenery collision leaves the full vehicle corridor clear")
		if id!="sunlit_cape":
			var minimum := route.points[0].y
			for point: Vector3 in route.points: minimum=minf(minimum,point.y)
			check(land.dressing.get_node("DistantValleyFloor").position.y<minimum-50,id+" background floor cannot cover any route elevation")
		if id=="sunlit_cape": check(land.sailboats.size()==4 and land.dressing.has_node("GoldenBeach") and land.dressing.has_node("GoldenCoastOverlook"),"Coastal finale includes sailing bay, beach and spectator overlook")
		if id=="misty_highlands": check(land.dressing.has_node("SummitBelvedere") and app.race.presentation.environment.fog_density<.0008,"Summit and clear foreground morning light exist")
		if id=="sunset_ridge": check(land.dressing.has_node("PineStoneArch"),"Forest has a natural stone arch")
		await app.leave_race()
		app.queue_free()
		await process_frame
	finish()

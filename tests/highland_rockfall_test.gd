extends "res://tests/test_suite.gd"


func _run() -> void:
	var definition := RallyContentCatalog.stage("misty_highlands")
	var modified := 0.0
	var mountain_left := 0.0
	var mountain_right := 0.0
	for section: Vector3 in definition.mountain_cliff_sections:
		modified += section.y-section.x
		if section.z<0: mountain_left += section.y-section.x
		else: mountain_right += section.y-section.x
	check(is_equal_approx(modified/definition.target_length,.7),"Mountain/cliff corridor covers exactly 70% of the authored route")
	check(mountain_left>mountain_right,"The ridge sits beside the left-hand edge for most transformed sections")
	check(definition.stage_version=="9","Cliff collision change isolates previous highland records and ghosts")
	var expected := PackedFloat32Array([450,900,1480,1930,2490])
	var actual: Array[float]=[]
	for note: Dictionary in definition.hazard_notes:
		if note.code=="ROCKFALL": actual.append(float(note.s))
	check(actual==Array(expected),"All five event points have fixed rockfall pacenotes")
	for position: float in expected:
		check(definition.mountain_side_at(position)!=0,"Rockfall %d is backed by an authored ridge"%position)
		check(definition.mountain_side_at(position)<0 if position<2200 else definition.mountain_side_at(position)>0,"Rockfall %d uses its section's mountain side"%position)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://highland-rockfall-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.chosen_stage="misty_highlands"
	app.practice=true
	await app.start_race()
	var scene: Node3D=app.race
	check(scene.wildlife.events.is_empty(),"Highland does not generate crossing wildlife")
	check(scene.rockfall.events.size()==5,"Highland builds five decorative rockfall groups")
	var playable_falls: Array[float]=[]
	for note: Dictionary in scene.generator.route.notes:
		if note.code=="ROCKFALL": playable_falls.append(float(note.s))
	check(playable_falls==Array(expected),"All five rockfall warnings survive runtime pacenote generation beside timber hazards")
	var announced: Array[float]=[]
	var run := RallyStageSession.new()
	run.setup(scene.generator.route)
	run.phase=RallyStageSession.Phase.RUNNING
	for station: int in range(8,2800,2):
		var previous_note := run.next_note
		run.step(scene.generator.route.position_at(station),15.0,2.0/15.0)
		if run.next_note!=previous_note and run.current_note=="ROCKFALL": announced.append(run.note_s)
	check(announced==Array(expected),"A real session announces every rockfall warning along the route")
	for station: float in [450.0,900.0,1930.0,2490.0]:
		var route: RallyStageRoute=scene.generator.route
		var center: Vector3=route.position_at(station)
		var right: Vector3=route.rights[route.index_at(station)]
		var left_height: float=scene.presentation.scenery.rendered_height_at((center-right*18.0).x,(center-right*18.0).z)
		var right_height: float=scene.presentation.scenery.rendered_height_at((center+right*18.0).x,(center+right*18.0).z)
		var mountain_is_left: bool=scene.challenge.stage.mountain_side_at(station)<0
		check(left_height>right_height+12 if mountain_is_left else right_height>left_height+12,"Mountain rise and cliff drop read from the roadside at %dm (road %.1f, left %.1f, right %.1f)"%[station,center.y,left_height,right_height])
	var road_is_clear := true
	var worst_clearance := INF
	for station: int in range(0,int(scene.generator.route.length),8):
		var half: float=scene.generator.route.width_at(station)*.5
		for lateral: float in [-half,0.0,half]:
			var road: Vector3=scene.generator.surface_position_at(station,lateral)
			var gap: float=road.y-scene.presentation.scenery.rendered_height_at(road.x,road.z)
			worst_clearance=minf(worst_clearance,gap)
			if gap<0.03: road_is_clear=false
	check(road_is_clear,"Rendered mountain triangles never cover the driveable lane (minimum clearance %.2fm)"%worst_clearance)
	var seam_count := 0
	var seams_are_smooth := true
	for ray: Vector2 in [Vector2(1930,1),Vector2(2490,-1)]:
		var origin: Vector3=scene.generator.route.position_at(ray.x)
		var right: Vector3=scene.generator.route.rights[scene.generator.route.index_at(ray.x)]*ray.y
		var previous_s: float=scene.presentation.scenery.nearest(origin+right*8.0).s
		for offset: int in range(9,101):
			var frame: Dictionary=scene.presentation.scenery.nearest(origin+right*offset)
			if absf(float(frame.s)-previous_s)>60:
				var low: float=offset-1
				var high: float=offset
				for iteration: int in range(12):
					var middle := (low+high)*.5
					var at: Dictionary=scene.presentation.scenery.nearest(origin+right*middle)
					if absf(float(at.s)-previous_s)<60: low=middle
					else: high=middle
				var a := origin+right*(low-.02)
				var b := origin+right*(high+.02)
				var jump: float=absf(scene.presentation.scenery.height_at(a.x,a.z)-scene.presentation.scenery.height_at(b.x,b.z))
				if jump>1: seams_are_smooth=false
				seam_count+=1
				break
			previous_s=frame.s
	check(seam_count>0 and seams_are_smooth,"Neighboring switchbacks blend continuously instead of forming vertical terrain curtains (%d seams checked)"%seam_count)
	var material: ShaderMaterial=scene.generator.road_visuals[0].material_override
	check(material.get_shader_parameter("mountain_section_count")==4,"The wide grass apron is masked in all four alpine sections")
	var baseline := RallyStageGenerator.new()
	baseline.definition=definition.duplicate(true)
	baseline.definition.mountain_cliff_sections=PackedVector3Array()
	baseline.route.build(baseline.definition)
	var same_geometry: bool=baseline.route.points==scene.generator.route.points
	for i: int in range(baseline.route.points.size()):
		for column: int in range(9):
			if not baseline.vertex_at(i,column).is_equal_approx(scene.generator.vertex_at(i,column)): same_geometry=false
	check(same_geometry,"Alpine scenery preserves the road vertex layout; outer collision apron is separately removed")
	baseline.free()
	var safe:=true
	for event: Dictionary in scene.rockfall.events:
		var station:=float(event.s)
		var lateral_side:=float(event.side)
		var flight_is_clear := true
		for stone: MeshInstance3D in event.items:
			var projection: Dictionary=scene.generator.route.project(stone.get_meta("finish"))
			var radius: float=maxf(stone.scale.x,stone.scale.z)
			var clearance: float=absf(float(projection.lateral))-scene.generator.route.width_at(station)*.5-radius
			if clearance<1.5: safe=false
			if stone.find_children("*","CollisionShape3D",true,false).size()>0: safe=false
			for sample: int in range(33):
				var at: Vector3=scene.rockfall.position_at_weight(stone,float(sample)/32)
				var nearest: Dictionary=scene.presentation.scenery.nearest(at)
				if absf(float(nearest.lateral))<scene.generator.route.width_at(nearest.s)*.5+radius+1.5:
					flight_is_clear=false
					print("FLIGHT GAP ",station," sample=",sample," actual=",absf(float(nearest.lateral))-scene.generator.route.width_at(nearest.s)*.5-radius)
				if at.y<scene.presentation.scenery.rendered_height_at(at.x,at.z)+stone.scale.y*.8: flight_is_clear=false
		check(safe,"Rockfall stones have no collisions and remain outside the road and vehicle clearance")
		check(flight_is_clear,"Every sampled fall stays above the visible mountainside and outside the road")
		check(lateral_side==signf(definition.mountain_side_at(station)),"Rocks descend from the adjacent mountainside")
	# Drive state is controlled explicitly to prove approach activation and reset behavior.
	scene.session.phase=RallyStageSession.Phase.RUNNING
	scene.vehicle.linear_velocity=Vector3.ZERO
	for event: Dictionary in scene.rockfall.events:
		scene.session.progress=float(event.s)-7
		scene.rockfall.advance(.1)
		check(float(event.elapsed)>0 and event.items.any(func(stone: MeshInstance3D)->bool:return stone.visible),"Approaching each marked point starts its non-colliding fall")
		for frame: int in range(50): scene.rockfall.advance(.1)
		check(event.items.all(func(stone: MeshInstance3D)->bool:return not stone.visible),"Each fall settles and clears after its short animation")
		scene.rockfall.reset()
		check(float(event.elapsed)<0,"Restart resets one-shot fall events")
	await app.leave_race()
	app.free()
	await process_frame
	finish()

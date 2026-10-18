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
	check(definition.stage_version=="7","Visual and audio additions preserve existing records and ghosts")
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
	await app.start_race()
	var scene: Node3D=app.race
	check(scene.wildlife.events.is_empty(),"Highland does not generate crossing wildlife")
	check(scene.rockfall.events.size()==5,"Highland builds five decorative rockfall groups")
	var safe:=true
	for event: Dictionary in scene.rockfall.events:
		var station:=float(event.s)
		var lateral_side:=float(event.side)
		for stone: MeshInstance3D in event.items:
			var projection: Dictionary=scene.generator.route.project(stone.get_meta("finish"))
			var radius: float=maxf(stone.scale.x,stone.scale.z)
			var clearance: float=absf(float(projection.lateral))-scene.generator.route.width_at(station)*.5-radius-scene.vehicle.config.body_size.x*.5
			if clearance<1.5: safe=false
			if stone.find_children("*","CollisionShape3D",true,false).size()>0: safe=false
		check(safe,"Rockfall stones have no collisions and remain outside the road and vehicle clearance")
		check(lateral_side==signf(definition.mountain_side_at(station)),"Rocks descend from the adjacent mountainside")
	# Drive state is controlled explicitly to prove approach activation and reset behavior.
	scene.session.phase=RallyStageSession.Phase.RUNNING
	scene.vehicle.linear_velocity=Vector3.ZERO
	for event: Dictionary in scene.rockfall.events:
		scene.session.progress=float(event.s)-7
		scene.rockfall.advance(.1)
		check(float(event.elapsed)>0 and event.items.any(func(stone: MeshInstance3D)->bool:return stone.visible),"Approaching each marked point starts its non-colliding fall")
		for frame: int in range(30): scene.rockfall.advance(.1)
		check(event.items.all(func(stone: MeshInstance3D)->bool:return not stone.visible),"Each fall settles and clears after its short animation")
		scene.rockfall.reset()
		check(float(event.elapsed)<0,"Restart resets one-shot fall events")
	await app.leave_race()
	app.free()
	await process_frame
	finish()

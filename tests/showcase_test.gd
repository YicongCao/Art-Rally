extends "res://tests/test_suite.gd"
var metrics := {"shots":[],"camera_rates":[],"event_visibility":{},"collision_sweep":{}}

func _run() -> void:
	root.size=Vector2i(1280,720)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://showcase-test/profile.json"
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	var before := JSON.stringify(app.profile.data)
	await app.start_benchmark()
	var demo := app.showcase
	check(is_instance_valid(demo) and demo.ready_to_play,"All three stages prepared before film clock starts")
	if not is_instance_valid(demo): finish(); return
	demo.set_process(false)
	var end := 0.0
	for shot: Dictionary in demo.shots:
		check(is_equal_approx(shot.start,end),"Contiguous shot: "+str(shot.id))
		end+=shot.duration
		var world: RallyShowcaseWorld=demo.worlds[shot.stage]
		var clip: Dictionary=world.clips[shot.clip]
		check(float(shot.source_in)+float(shot.duration)<clip.recording.duration,"Recording covers "+str(shot.id))
		check(clip.source=="physical_input_recording" and clip.physics_hz==120 and clip.sample_hz==60 and clip.tier==0,"Stock physical recording: "+str(shot.id))
		var speeds: Array[float]=[]
		var max_lateral := 0.0
		for row: Array in clip.telemetry:
			if row[0]<shot.source_in or row[0]>shot.source_in+shot.duration: continue
			speeds.append(row[2]*3.6)
			max_lateral=maxf(max_lateral,absf(row[9]))
		speeds.sort()
		metrics.shots.append({"id":shot.id,"speed_kph_min":speeds[0],"speed_kph_median":speeds[speeds.size()/2],"speed_kph_max":speeds[-1],"max_lateral_m":max_lateral})
		var hit_names := {}
		var max_pose_error := 0.0
		for tick: int in range(int(shot.duration*60)):
			var t: float=shot.source_in+float(tick)/60
			var pose: Transform3D=RallyGhostRecording.sample(clip.recording,t).pose
			var shape := BoxShape3D.new()
			shape.size=Vector3(world.scene.challenge.vehicle.body_size.x,.65,world.scene.challenge.vehicle.body_size.z)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape=shape
			query.transform=pose*Transform3D(Basis.IDENTITY,Vector3(0,.25,0))
			query.collision_mask=1
			query.exclude=[world.scene.vehicle.get_rid()]
			for hit: Dictionary in world.scene.get_world_3d().direct_space_state.intersect_shape(query,16):
				var name_id := str(hit.collider.name)
				if not name_id.begins_with("Road"): hit_names[name_id]=true
			var delta: Vector3=RallyGhostRecording.sample(clip.recording,t+1.0/60).pose.origin-pose.origin
			max_pose_error=maxf(max_pose_error,absf(delta.length()*60-RallyShowcaseWorld.telemetry_at(clip,t)[2]))
		metrics.collision_sweep[shot.id]={"contacts":hit_names.keys(),"max_speed_pose_error_mps":max_pose_error}
		check(hit_names.is_empty(),"Full scene body sweep clear: "+str(shot.id)+" "+str(hit_names.keys()))
		check(max_pose_error<1.5,"Pose displacement agrees with speed telemetry: "+str(shot.id))
	check(is_equal_approx(end,75),"Exactly 75 seconds at 1x playback")
	var hero: Dictionary=demo.worlds.sunset_ridge.clips.recovery
	var peak := 0.0
	var peak_time := 0.0
	var stable := 0.0
	var longest := 0.0
	var countersteer := false
	var handbrake := false
	for row: Array in hero.telemetry:
		if row[0]<7 or row[0]>19: continue
		if absf(row[3])>peak: peak=absf(row[3]); peak_time=row[0]
		if row[0]>11 and absf(row[3])<4: stable+=1.0/60; longest=maxf(longest,stable)
		else: stable=0
		if row[0]>10.5 and row[0]<12 and row[4]>.2: countersteer=true
		handbrake=handbrake or row[10]>.001
	metrics.recovery={"peak_sideslip_deg":peak,"peak_source_time":peak_time,"continuous_under_4_deg_seconds":longest,"countersteer":countersteer,"handbrake":handbrake,"collisions":hero.collisions}
	check(peak>=15 and peak<=25 and longest>=2 and countersteer and not handbrake and hero.collisions==0 and hero.recording.gaps.is_empty(),"Continuous real oversteer, opposite lock and recovery")
	check(hero.esp==0 and hero.tc==0 and hero.abs,"Recording-only ABS on, ESP/TC off")
	for fps: int in [30,60,120]:
		for shot_index: int in [2,3,6]:
			var shot: Dictionary=demo.shots[shot_index]
			var world: RallyShowcaseWorld=demo.worlds[shot.stage]
			var previous := RallyShowcaseCamera.evaluate(world,shot,shot.start)
			var max_angle := 0.0
			var max_step := 0.0
			var min_clearance := 1000.0
			for tick: int in range(1,int(shot.duration*fps)):
				var t: float=shot.start+float(tick)/fps
				var frame := RallyShowcaseCamera.evaluate(world,shot,t)
				max_angle=maxf(max_angle,rad_to_deg(previous.pose.basis.get_rotation_quaternion().angle_to(frame.pose.basis.get_rotation_quaternion())))
				max_step=maxf(max_step,previous.pose.origin.distance_to(frame.pose.origin))
				var ground: float=world.scene.presentation.scenery.rendered_height_at(frame.pose.origin.x,frame.pose.origin.z)
				min_clearance=minf(min_clearance,frame.pose.origin.y-ground)
				previous=frame
			metrics.camera_rates.append({"fps":fps,"shot":shot.id,"max_angle_per_frame_deg":max_angle,"max_position_step_m":max_step,"min_ground_clearance_m":min_clearance})
			check(max_angle<4 and max_step<2 and min_clearance>.15,"Stable camera at %d FPS: %s"%[fps,shot.id])
	# Director ownership: no stage/vehicle/input tick may overwrite a held pose.
	demo.seek(13)
	var fixed: Transform3D=demo.worlds.sunset_ridge.scene.camera.transform
	for i: int in range(5): await process_frame
	check(fixed.is_equal_approx(demo.worlds.sunset_ridge.scene.camera.transform),"Normal camera cannot overwrite director")
	for world: RallyShowcaseWorld in demo.worlds.values():
		check(not world.scene.is_processing() and not world.scene.is_physics_processing() and not world.scene.vehicle.is_physics_processing() and not world.scene.controls.is_processing_input(),"Runtime and controls disabled in "+str(world.viewport.name))
	for world: RallyShowcaseWorld in demo.worlds.values(): world.scene.controls.safety_pause_requested.emit()
	check(not paused,"Dormant driving controllers cannot pause the shared SceneTree")
	# Send actual GUI/input events rather than invoking button callbacks.
	var key := InputEventKey.new()
	key.physical_keycode=KEY_SPACE
	key.pressed=true
	root.push_input(key)
	check(not demo.playing and demo.pause_panel.visible,"Space pauses film through Viewport input")
	var paused_clock := demo.clock
	demo._process(1)
	check(demo.clock==paused_clock,"Paused editorial clock does not advance")
	var joy := InputEventJoypadButton.new()
	joy.button_index=JOY_BUTTON_START
	joy.pressed=true
	root.push_input(joy)
	check(demo.playing and not demo.pause_panel.visible,"Controller Start resumes through Viewport input")
	for id: String in ["animals","helicopter","bridge"]:
		var shot: Dictionary=demo.shots[4 if id=="animals" else (8 if id=="helicopter" else 7)]
		var visible_seconds := 0.0
		var longest_visible := 0.0
		for tick: int in range(int(shot.duration*30)):
			demo.seek(shot.start+float(tick)/30)
			var world: RallyShowcaseWorld=demo.worlds[shot.stage]
			var point: Vector3=world.scene.wildlife.deer.position+Vector3.UP if id=="animals" else (world.scene.broadcast.airframe.position if id=="helicopter" else world.scene.generator.route.position_at(770))
			var camera: Camera3D=world.scene.camera
			var xy := camera.unproject_position(point)/Vector2(world.viewport.size)
			var visible := not camera.is_position_behind(point) and xy.x>.04 and xy.x<.96 and xy.y>.04 and xy.y<.96
			if id!="animals":
				var car_xy := camera.unproject_position(world.actor.position)/Vector2(world.viewport.size)
				visible=visible and not camera.is_position_behind(world.actor.position) and Rect2(.02,.02,.96,.96).has_point(car_xy)
			if visible: visible_seconds+=1.0/30; longest_visible=maxf(longest_visible,visible_seconds)
			else: visible_seconds=0
		metrics.event_visibility[id]=longest_visible
		check(longest_visible>=2,"At least 2 seconds continuously framed: "+id)
	var animal_world: RallyShowcaseWorld=demo.worlds.sunset_ridge
	var animal_shot: Dictionary=demo.shots[4]
	var animal_clip: Dictionary=animal_world.clips[animal_shot.clip]
	var crossing_s: float=RallyShowcaseWorld.telemetry_at(animal_clip,animal_shot.source_in+5.8)[1]
	var clear_at: float= (55+animal_world.scene.generator.route.width_at(crossing_s)*.5+2.0)/6.25-7.0
	var safety_gap: float= 5.8-clear_at-2.0/21.0
	metrics.animal_safety_gap_seconds=safety_gap
	check(safety_gap>=3,"Deer body clears carriageway at least 3 seconds before car nose")
	demo.seek(29.1)
	var deer_pose: Transform3D=demo.worlds.sunset_ridge.scene.wildlife.deer.transform
	demo.restart()
	demo.seek(29.1)
	check(deer_pose.is_equal_approx(demo.worlds.sunset_ridge.scene.wildlife.deer.transform),"Restart reproduces wildlife event")
	check(JSON.stringify(app.profile.data)==before,"Player profile, settings, scores and unlocks unchanged")
	check(not FileAccess.file_exists("user://showcase-test/profile.json"),"No profile written by demo")
	demo.seek(74.99)
	demo._process(.02)
	check(app.showcase==demo and not demo.visible and app.screen=="showcase_result","75 seconds ends on replay/home page")
	app._showcase_replay()
	check(app.showcase==demo and demo.clock==0 and demo.playing and app.screen=="showcase","Replay reuses prepared worlds with no loading page")
	demo.seek(74.99)
	demo._process(.02)
	await process_frame
	var back := InputEventKey.new()
	back.physical_keycode=KEY_ESCAPE
	back.keycode=KEY_ESCAPE
	back.pressed=true
	root.push_input(back)
	check(app.showcase==null and app.screen=="home","Escape on result page exits; hidden director cannot capture menu input")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/brushline/showcase/validation"))
	FileAccess.open("res://docs/brushline/showcase/validation/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	app.free()
	await process_frame
	finish()

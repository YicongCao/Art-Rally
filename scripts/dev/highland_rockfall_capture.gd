extends SceneTree

var app: RallyGameApp

func _initialize() -> void: _run.call_deferred()


func _run() -> void:
	var full_drive := "--full-drive" in OS.get_cmdline_user_args()
	root.size=Vector2i(1920,1080) if full_drive else Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	if full_drive: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://highland-rockfall-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="BRUSHLINE"
	app.chosen_stage="misty_highlands"
	app.chosen_vehicle="A240"
	AudioServer.set_bus_mute(0,true)
	await app.start_race()
	var scene: Node3D=app.race
	if full_drive:
		var passed := await _full_drive(scene)
		await app.leave_race()
		app.free()
		await process_frame
		quit(0 if passed else 1)
		return
	var route: RallyStageRoute=scene.generator.route
	for index: int in range(RallyRockfall.ROCKFALL_SITES.size()):
		var station: float=RallyRockfall.ROCKFALL_SITES[index]
		var start := station-50.0
		var pose := route.pose_at(start)
		scene._set_autopilot_mode_name("off")
		scene.session.projection_hint=route.index_at(start)
		scene.session.previous=pose.origin
		scene.session.progress=start
		scene.session.next_gate=1
		while scene.session.gates[scene.session.next_gate]<start: scene.session.next_gate+=1
		scene.session.next_note=0
		while scene.session.next_note<route.notes.size() and route.notes[scene.session.next_note].s<start: scene.session.next_note+=1
		scene.session.phase=RallyStageSession.Phase.RUNNING
		scene.respawn_wait=true
		scene.vehicle.request_reset(pose)
		scene.presentation.camera_rig.reset()
		scene.rockfall.reset()
		for event: Dictionary in scene.rockfall.events:
			if event.s<start: event.elapsed=RallyRockfall.ROCKFALL_DURATION
		for frame: int in range(30):
			if paused or scene.controls.blocked:
				paused=false
				scene.controls.resume()
			scene.pause_menu.hide()
			await process_frame
		scene.auto_driver.begin_run(route,scene.vehicle.position)
		scene._set_autopilot_mode_name("vgamepad")
		var wall_start := Time.get_ticks_msec()
		var rendered_frames := 0
		# Capture after real production physics, camera and rockfall updates.
		# These are the player's chase view, rather than a hand-placed camera.
		for frame: int in range(120*25):
			if paused or scene.controls.blocked:
				paused=false
				scene.controls.resume()
			scene.pause_menu.hide()
			await process_frame
			rendered_frames+=1
			if scene.session.progress>=station-4: break
			if Time.get_ticks_msec()-wall_start>25000: break
		if scene.session.progress<station-4:
			push_error("Highland capture did not reach %dm under production driving"%station)
			quit(1)
			return
		# Inspect the near-miss itself, not only the road before activation.
		var fall: Dictionary=scene.rockfall.events[index]
		var deadline := Time.get_ticks_msec()+6000
		while float(fall.elapsed)<2.7 and Time.get_ticks_msec()<deadline:
			await process_frame
		await RenderingServer.frame_post_draw
		print("NEAR MISS ",index," elapsed=",fall.elapsed," clearance=",scene.rockfall.closest_clearance)
		var path: String="res://docs/brushline/rockfall-%02d.jpg"%index
		root.get_texture().get_image().save_jpg(path,.94)
		print("SAVED ",path," progress=",scene.session.progress," recoveries=",scene.session.reset_count," average_fps=",rendered_frames*1000.0/maxi(1,Time.get_ticks_msec()-wall_start))
	await app.leave_race()
	app.free()
	await process_frame
	quit()


func _full_drive(scene: Node3D) -> bool:
	scene._set_autopilot_mode_name("vgamepad")
	var frames: Array[float]=[]
	var physics: Array[float]=[]
	var elapsed := 0.0
	var previous := Time.get_ticks_usec()
	var photo := 0
	var next_report := 30.0
	while scene.session.phase!=RallyStageSession.Phase.FINISHED and elapsed<650:
		if paused or scene.controls.blocked:
			paused=false
			scene.controls.resume()
		scene.pause_menu.hide()
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now-previous)/1000.0
		previous=now
		elapsed+=ms/1000.0
		if elapsed>5:
			frames.append(ms)
			physics.append(scene.vehicle.physics_usec/1000.0)
		if photo<RallyRockfall.ROCKFALL_SITES.size() and scene.session.progress>=RallyRockfall.ROCKFALL_SITES[photo]-4:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg("res://docs/brushline/rockfall-%02d.jpg"%photo,.94)
			print("HIGHLAND PHOTO ",photo," progress=",scene.session.progress)
			photo+=1
		if elapsed>=next_report:
			print("HIGHLAND DRIVE progress=",scene.session.progress," time=",scene.session.elapsed," recoveries=",scene.session.reset_count)
			next_report+=30
	frames.sort()
	physics.sort()
	var total_ms := 0.0
	for frame: float in frames: total_ms+=frame
	var report := {"stage":"misty_highlands","vehicle":"A240","resolution":[1920,1080],"finished":scene.session.phase==RallyStageSession.Phase.FINISHED,"elapsed":scene.session.elapsed,"recoveries":scene.session.reset_count,"photos":photo,"average_fps":1000.0*frames.size()/maxf(1,total_ms),"frame_p95_ms":frames[int(frames.size()*.95)],"physics_p95_ms":physics[int(physics.size()*.95)],"renderer":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open("res://logs/highland_review_drive.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("HIGHLAND FULL DRIVE: ",JSON.stringify(report))
	return report.finished and report.recoveries==0 and photo==5

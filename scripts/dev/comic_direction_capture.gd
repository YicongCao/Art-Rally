extends SceneTree
var app: RallyGameApp
var viewport: SubViewport
const DEST := "res://docs/art-direction/comic-hud"
func _initialize() -> void: _run.call_deferred()
func frame() -> void:
	if is_instance_valid(app.race):
		if paused or app.race.controls.blocked:
			paused=false
			app.race.controls.resume()
		app.race.pause_menu.show_menu(false)
	await process_frame
func snap(label: String) -> void:
	for i: int in range(8): await frame()
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image.get_size()==viewport.size)
	image.save_jpg(DEST+"/"+label+".jpg",.94)
	print("COMIC CAPTURE: ",label)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	viewport=SubViewport.new()
	viewport.size=Vector2i(1920,1080)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.texture=viewport.get_texture()
	root.add_child(display)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://comic-direction-review/profile.json"
	viewport.add_child(app)
	AudioServer.set_bus_mute(0,true)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="ART-RALLY"
	var report := {}
	for index: int in range(3):
		app.chosen_stage=RallyContentCatalog.STAGES[index]
		app.chosen_vehicle=RallyContentCatalog.VEHICLES[index]
		await app.start_race()
		var route: RallyStageRoute=app.race.generator.route
		var station: float=[430,1390,1580][index]
		var pose := route.pose_at(station)
		app.race.session.projection_hint=route.index_at(station)
		app.race.session.previous=pose.origin
		app.race.session.progress=station
		while app.race.session.gates[app.race.session.next_gate]<station:app.race.session.next_gate+=1
		app.race.session.phase=RallyStageSession.Phase.RUNNING
		app.race.vehicle.request_reset(pose)
		app.race._set_autopilot_mode_name("vgamepad")
		app.race.auto_driver.reset_navigation(route,pose.origin)
		app.race.camera_snap=true
		for i: int in range(120):await frame()
		await snap(app.chosen_stage)
		if index==0:
			app.race.session.current_note="LEFT_TIGHT"
			app.race.session.note_remaining=5
			app.race.session.note_s=app.race.session.progress+80
			await snap("hud-left")
			app.race.session.current_note="RIGHT_MEDIUM"
			app.race.session.note_remaining=5
			await snap("hud-right")
			viewport.size=Vector2i(1280,720)
			await snap("hud-720p")
			viewport.size=Vector2i(1920,1080)
		var times: Array[float]=[]
		for i: int in range(180):
			var start := Time.get_ticks_usec()
			await frame()
			times.append((Time.get_ticks_usec()-start)/1000.0)
		times.sort()
		report[app.chosen_stage]={"actual_pixels":"1920x1080","sample_frames":times.size(),"p95_wall_ms":times[int(times.size()*.95)],"p99_wall_ms":times[int(times.size()*.99)],"progress_m":app.race.session.progress-station,"post_count":app.race.presentation.road_posts.poses.size(),"note":"Short native capture sample, not full-stage benchmark."}
		assert(app.race.session.progress>station+15,"Autopilot must advance during native sample")
		if index==0:
			# Inspect an intact corridor from its road centre, then a physical hit.
			app.race._set_autopilot_mode_name("off")
			var posts: RallyBreakablePosts = app.race.presentation.road_posts
			var at: Vector3=posts.poses[4].origin
			var camera := Camera3D.new()
			app.race.add_child(camera)
			camera.fov=58
			camera.far=6200
			camera.global_position=at-route.tangent_at(route.length*.06+24)*9+Vector3.UP*2.3
			camera.look_at(at+Vector3.UP*.65)
			camera.make_current()
			app.race.game_hud.modulate.a=0
			await snap("posts-intact")
			var hit_pose := Transform3D(Basis.looking_at(route.tangent_at(route.length*.06+24)),at+Vector3.UP*.8)
			app.race.vehicle.request_reset(hit_pose)
			for i: int in range(3):await frame()
			app.race.vehicle.linear_velocity=route.tangent_at(route.length*.06+24)*12
			for i: int in range(12):await frame()
			await snap("posts-impact")
			report[app.chosen_stage]["physical_post_hits"]=posts.hits
			assert(posts.hits>0,"Actual car sweep must fracture a post")
			app.race.camera.make_current()
			camera.queue_free()
		await app.leave_race()
	FileAccess.open(DEST+"/capture-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("COMIC CAPTURE PASSED")
	viewport.queue_free()
	await process_frame
	quit()

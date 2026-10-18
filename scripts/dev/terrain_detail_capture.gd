extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://terrain-detail-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="ART RALLY"
	AudioServer.set_bus_mute(0,true)
	for stage: String in ["sunset_ridge","misty_highlands"]:
		root.size=Vector2i(1280,720) if stage=="sunset_ridge" else Vector2i(1920,1080)
		DisplayServer.window_set_size(root.size)
		app.chosen_stage=stage
		await app.start_race()
		var scene: Node3D=app.race
		paused=true
		scene.set_process(false)
		scene.game_hud.hide()
		var land: RallyStageScenery=scene.presentation.scenery
		var pile: Node3D=land.log_piles[0]
		scene.camera.position=pile.transform*Vector3(-4.5,3.4,8)
		scene.camera.look_at(pile.transform*Vector3(0,1,0))
		await shot(scene,stage+"-timber")
		var station: float=pile.get_meta("station")
		var at: Transform3D=scene.generator.route.pose_at(station-18,0)
		scene.camera.position=at.origin+Vector3.UP*3.5+at.basis.z*7
		scene.camera.look_at(scene.generator.route.position_at(station)+Vector3.UP*.8)
		var data: Dictionary=RallyHUD.data_for(scene.vehicle,scene.session,false)
		data.stage_title=RallyContentCatalog.stage(stage).title
		data.surface=scene.generator.definition.surface_id(station)
		data.note="LOGS"
		data.note_distance=36
		data.speed=58
		data.phase=RallyStageSession.Phase.RUNNING
		scene.game_hud.refresh(data)
		scene.game_hud.show()
		await shot(scene,stage+"-approach")
		scene.game_hud.hide()
		if stage=="misty_highlands":
			var worst := 0.0
			var tree := Vector3.ZERO
			for item: Dictionary in land.foliage.placements:
				if item.kind!="pine" or absf(item.lateral)<30: continue
				var p: Vector3=item.point
				var error := land.height_at(p.x,p.z)-p.y
				if error>worst:
					worst=error
					tree=p
			scene.camera.position=tree+Vector3(19,12,24)
			scene.camera.look_at(tree+Vector3.UP*3)
			await shot(scene,"highland-grounded-trees")
			print("TREE HEIGHT CORRECTION: ",worst)
		await app.leave_race()
	app.free()
	await process_frame
	print("TERRAIN DETAIL CAPTURE PASSED")
	quit()
func shot(scene: Node3D,title: String) -> void:
	await process_frame
	scene.pause_menu.hide()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/terrain-"+title+".jpg",.94)

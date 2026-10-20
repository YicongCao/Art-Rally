extends SceneTree

# Native scene captures with deliberate readout extremes, isolated from player saves.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://gauge-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="BRUSHLINE"
	AudioServer.set_bus_mute(0,true)
	for stage_id: String in ["sunset_ridge","sunlit_cape"]:
		root.size=Vector2i(1280,720) if stage_id=="sunset_ridge" else Vector2i(1920,1080)
		DisplayServer.window_set_size(root.size)
		app.chosen_stage=stage_id
		await app.start_race()
		var scene: Node3D=app.race
		scene._set_autopilot_mode_name("vgamepad")
		for i: int in range(240): await physics_frame
		paused=true
		scene.set_process(false)
		var data: Dictionary=RallyHUD.data_for(scene.vehicle,scene.session,false)
		data.stage_title="夕照松岭" if stage_id=="sunset_ridge" else "晴岬海岸"
		data.phase=RallyStageSession.Phase.RUNNING
		data.speed=128 if stage_id=="sunset_ridge" else 236
		data.gear="4" if stage_id=="sunset_ridge" else "6"
		data.rpm=5200 if stage_id=="sunset_ridge" else 7500
		data.redline=7600
		data.throttle=.72
		data.brake=.0
		data.handbrake=0
		scene.game_hud.refresh(data)
		scene.game_hud.hint_alpha=0
		await process_frame
		scene.pause_menu.hide()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("res://docs/previews/retro-gauge-"+stage_id+".jpg",.95)
		# R / zero-speed / handbrake must fit the same layout without moving labels.
		data.speed=0
		data.gear="R"
		data.rpm=900
		data.handbrake=1
		scene.game_hud.refresh(data)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("res://docs/previews/retro-gauge-"+stage_id+"-reverse.jpg",.95)
		await app.leave_race()
	app.free()
	await process_frame
	var viewport := SubViewport.new()
	viewport.size=Vector2i(768,300)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var cockpit := RallyCockpitDisplay.new()
	viewport.add_child(cockpit)
	cockpit.speed=128
	cockpit.gear="4"
	cockpit.rpm=5200
	cockpit.throttle=.72
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://docs/previews/retro-cockpit.png")
	viewport.free()
	await process_frame
	print("RETRO GAUGE CAPTURE PASSED: 720p / 1080p, forward / reverse, cockpit")
	quit()

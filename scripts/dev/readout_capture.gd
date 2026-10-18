extends SceneTree

# Native readout/layout validation, always isolated from the player's profile.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if "--cockpit" in OS.get_cmdline_user_args():
		await cockpit_shots()
		quit()
		return
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://readout-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="ART RALLY"
	app.chosen_stage="misty_highlands"
	app.chosen_vehicle="F160"
	AudioServer.set_bus_mute(0,true)
	await app.start_race()
	var scene: Node3D=app.race
	scene._set_autopilot_mode_name("vgamepad")
	for i: int in range(480): await physics_frame
	paused=true
	scene.set_process(false)
	var data: Dictionary=RallyHUD.data_for(scene.vehicle,scene.session,false)
	data.stage_title="雾杉高地 · F160"
	data.time=754.567
	data.best_time=744.235
	data.penalty=15
	data.phase=RallyStageSession.Phase.RUNNING
	data.gear="2"
	data.rpm=4200
	data.note="RIGHT_MEDIUM"
	data.note_distance=92
	data.split_times=[68.35]
	data.best_splits=[69.21]
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		DisplayServer.window_set_size(resolution)
		for speed: int in [7,99,100]:
			data.speed=speed
			scene.game_hud.refresh(data)
			scene.game_hud.sector_clock=1
			scene.game_hud.hint_alpha=0
			await process_frame
			scene.pause_menu.hide()
			await shot("hud-%d-%d"%[resolution.y,speed])
	# Close rear views keep the same real mesh and font as driving.
	scene.game_hud.hide()
	var plates: RallyVehiclePlate=scene.find_children("PlayerLicensePlates","",true,false)[0]
	var target: Node3D=plates.get_node("Rear")
	scene.camera.global_position=target.global_position+target.global_basis.z*2+Vector3.UP*.35
	scene.camera.look_at(target.global_position+Vector3.UP*.12)
	for value: String in ["RALLY","WWWWWWWWWW","沪A·山野拉力016"]:
		plates.set_text(value)
		await shot("plate-"+str(value.length())+value.left(1))
	await app.leave_race()
	app._loading_page()
	await create_timer(.4).timeout
	await shot("loading")
	app.free()
	await process_frame
	print("READOUT CAPTURE PASSED: 720p / 1080p, 2 / 3 digits, sectors, plates, loading")
	quit()
func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/readout-"+title+".jpg",.94)

func cockpit_shots() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(768,300)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var cockpit := RallyCockpitDisplay.new()
	viewport.add_child(cockpit)
	cockpit.gear="2"
	cockpit.rpm=4200
	for speed: int in [7,100]:
		cockpit.speed=speed
		cockpit.queue_redraw()
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://docs/previews/readout-cockpit-%d.png"%speed)
	viewport.free()
	await process_frame
	print("COCKPIT CAPTURE PASSED")

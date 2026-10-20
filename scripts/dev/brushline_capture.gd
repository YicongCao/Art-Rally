extends SceneTree
var app: RallyGameApp
var view: SubViewport
func _initialize() -> void: _run.call_deferred()
func snap(label: String) -> void:
	for i: int in range(40): await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_jpg("res://docs/brushline/"+label+".jpg",.94)
	print("BRUSHLINE SNAP ",label)
func _run() -> void:
	view=SubViewport.new()
	view.size=Vector2i(1280,720)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.texture=view.get_texture()
	root.add_child(display)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://brushline-visual/profile.json"
	view.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="BRUSHLINE"
	app.profile.data.unlocked_stages=Array(RallyContentCatalog.STAGES)
	AudioServer.set_bus_mute(0,true)
	app.show_home()
	await snap("home-720")
	app.show_stages()
	await snap("stages-720")
	app.show_vehicles()
	await snap("vehicles-720")
	app._loading_page()
	await snap("loading-720")
	view.size=Vector2i(1920,1080)
	for i: int in range(3):
		app.chosen_stage=RallyContentCatalog.STAGES[i]
		app.chosen_vehicle=RallyContentCatalog.VEHICLES[i]
		await app.start_race()
		var race: Node3D=app.race
		var station: float=[430,1390,1580][i]
		var pose: Transform3D=race.generator.route.pose_at(station)
		race.session.projection_hint=race.generator.route.index_at(station)
		race.session.previous=pose.origin
		race.session.progress=station
		while race.session.gates[race.session.next_gate]<station: race.session.next_gate+=1
		race.session.phase=RallyStageSession.Phase.RUNNING
		race.vehicle.request_reset(pose)
		race._set_autopilot_mode_name("vgamepad")
		race.auto_driver.reset_navigation(race.generator.route,pose.origin)
		race.controls.resume()
		paused=false
		for frame: int in range(150): await process_frame
		await snap(app.chosen_stage)
		await app.leave_race("home")
	app.queue_free()
	display.queue_free()
	view.queue_free()
	await process_frame
	quit()

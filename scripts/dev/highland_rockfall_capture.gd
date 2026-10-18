extends SceneTree

var app: RallyGameApp

func _initialize() -> void: _run.call_deferred()


func _run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://highland-rockfall-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="ART RALLY"
	app.chosen_stage="misty_highlands"
	app.chosen_vehicle="A240"
	AudioServer.set_bus_mute(0,true)
	await app.start_race()
	var scene: Node3D=app.race
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.vehicle.freeze=true
	scene.pause_menu.hide()
	scene.game_hud.hide()
	var route: RallyStageRoute=scene.generator.route
	var station:=450.0
	var at:=route.position_at(station-6)
	scene.vehicle.global_position=at+Vector3.UP*.82
	scene.vehicle.global_basis=route.pose_at(station-6).basis
	scene.session.phase=RallyStageSession.Phase.RUNNING
	scene.session.progress=station-6
	for index: int in range(3):
		scene.rockfall.advance(.65)
		scene.presentation.camera_rig.update(scene.camera,scene.vehicle,0,false,false,.65,Vector2.ZERO)
		# Hold a deliberate forward-facing chase composition for inspection; the
		# production camera remains untouched during normal gameplay.
		scene.camera.global_position=route.position_at(station-31)+Vector3.UP*6+route.rights[route.index_at(station)]*3
		scene.camera.look_at(route.position_at(station+14)+Vector3.UP*1.1)
		await RenderingServer.frame_post_draw
		var path: String="res://docs/previews/highland-rockfall-%02d.jpg"%index
		root.get_texture().get_image().save_jpg(path,.94)
		print("SAVED ",path)
	await app.leave_race()
	app.free()
	await process_frame
	quit()

extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://logs/rockfall-crossing")
	DirAccess.make_dir_recursive_absolute("res://docs/validation/rockfall-crossing")
	root.size=Vector2i(1280,720)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://rockfall-crossing-%d/profile.json"%OS.get_process_id()
	root.add_child(app)
	app.chosen_stage="misty_highlands"
	app.practice=true
	await app.start_race()
	var scene: Node3D=app.race
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.vehicle.freeze=true
	scene.game_hud.hide()
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov=70
	camera.make_current()
	AudioServer.set_bus_mute(0,true)
	for index: int in range(scene.rockfall.events.size()):
		var event: Dictionary=scene.rockfall.events[index]
		var station: float=event.s
		var pose: Transform3D=scene.generator.route.pose_at(station,0)
		camera.global_position=pose.origin-pose.basis.z*32-pose.basis.x*float(event.side)*42+Vector3.UP*20
		camera.look_at(pose.origin+Vector3.UP*8)
		scene.vehicle.global_transform=scene.generator.route.pose_at(station-30)
		scene.vehicle.linear_velocity=Vector3.ZERO
		scene.session.phase=RallyStageSession.Phase.RUNNING
		scene.session.progress=station-30
		scene.rockfall.reset()
		for frame: int in range(330):
			paused=false
			scene.controls.resume()
			scene.pause_menu.hide()
			scene.rockfall.advance(1.0/30)
			await process_frame
			await RenderingServer.frame_post_draw
			if index==0:
				root.get_texture().get_image().save_png("res://logs/rockfall-crossing/frame-%04d.png"%frame)
			if frame in [29,89,119,179,299]:
				root.get_texture().get_image().save_jpg("res://docs/validation/rockfall-crossing/site-%d-frame-%03d.jpg"%[index,frame],.9)
		print("CAPTURE site=",station," final=",event.items[0].global_position)
	app.free()
	await process_frame
	quit()

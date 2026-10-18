extends SceneTree
var app: RallyGameApp
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://v030-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="RALLY 030"
	app.profile.data.unlocked_power_tier=2
	AudioServer.set_bus_mute(0,true)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		DisplayServer.window_set_size(resolution)
		for stage: String in RallyContentCatalog.STAGES:
			app.chosen_stage=stage
			app._loading_page()
			app.progress_bar.value=45
			await shot("loading-%s-%d"%[stage,resolution.y])
		app.chosen_vehicle="R200"
		app.chosen_power_tier=1
		app.show_vehicles()
		await shot("selection-%d"%resolution.y)
	if "--menus-only" in OS.get_cmdline_user_args():
		app.free()
		await process_frame
		print("V030 MENU CAPTURE PASSED")
		quit()
		return
	await app.start_race()
	var scene: Node3D=app.race
	for i: int in range(120): await physics_frame
	paused=true
	scene.set_process(false)
	scene.game_hud.hide()
	var wheel: Node3D=scene.vehicle.wheel_visuals[0]
	scene.camera.global_position=wheel.global_position+scene.vehicle.basis*Vector3(-1.25,.30,-.8)
	scene.camera.look_at(wheel.global_position)
	await process_frame
	scene.pause_menu.hide()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/v030-wheel-close.jpg",.96)
	scene.camera.global_position=scene.vehicle.global_position+scene.vehicle.basis*Vector3(-3,1.2,4.4)
	scene.camera.look_at(scene.vehicle.global_position)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/v030-car-wheels.jpg",.95)
	scene.presentation.camera_rig.reset()
	for i: int in range(50): scene.presentation.camera_rig.update(scene.camera,scene.vehicle,0,false,false,1.0/60,Vector2(.7,-.25))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/v030-orbit.jpg",.94)
	await app.leave_race()
	app.free()
	await process_frame
	print("V030 POLISH CAPTURE PASSED")
	quit()
func shot(name_id: String) -> void:
	await create_timer(.65).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/v030-"+name_id+".jpg",.94)

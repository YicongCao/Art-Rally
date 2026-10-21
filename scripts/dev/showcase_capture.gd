extends SceneTree
var app: RallyGameApp
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://showcase-capture/profile.json"
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	await app.start_benchmark()
	var demo: RallyShowcaseDirector=app.showcase
	if not is_instance_valid(demo): quit(1); return
	demo.set_process(false)
	demo.playing=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/brushline/showcase/previews"))
	var requested := -1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): requested=int(arg.trim_prefix("--shot="))
	for i: int in range(demo.shots.size()):
		if requested>=0 and requested!=i: continue
		var shot: Dictionary=demo.shots[i]
		var time: float=shot.start+({"animals":1.1,"recovery":3.82}.get(shot.id,shot.duration*.5))
		demo.seek(time)
		for frame: int in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("res://docs/brushline/showcase/previews/%02d-%s.jpg"%[i+1,shot.id],.93)
		print("SHOT ",i+1," ",shot.id," ",time)

	if "--hood-probe" in OS.get_cmdline_user_args():
		demo.seek(43)
		var world: RallyShowcaseWorld=demo.worlds.sunlit_cape
		for variant: String in ["no_flare","no_actor","lower"]:
			world.scene.presentation.flare.overlay.hide()
			if variant=="no_actor": world.actor.hide()
			if variant=="lower":
				world.actor.show()
				var pose := world.actor.transform
				world.scene.camera.position=pose*Vector3(0,.65,-1.05)
				world.scene.camera.look_at(world.scene.camera.position-pose.basis.z*45-pose.basis.y*3,pose.basis.y)
			for frame: int in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg("res://logs/showcase/hood-%s.jpg"%variant,.93)

	if "--ui-check" in OS.get_cmdline_user_args():
		demo.seek(20)
		demo.set_playing(false)
		for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=resolution
			DisplayServer.window_set_size(resolution)
			for frame: int in range(10): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg("res://docs/brushline/showcase/validation/pause-%d.jpg"%resolution.x,.9)
		app._showcase_finished()
		for frame: int in range(30): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("res://docs/brushline/showcase/validation/end-1920.jpg",.9)
	app.free()
	await process_frame
	quit()

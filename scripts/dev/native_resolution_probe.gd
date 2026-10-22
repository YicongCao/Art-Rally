extends SceneTree
# Report the real pixel size of each 3D screen in a scaled window and save
# side-by-side crops. Usage (2x window simulates Retina):
#   godot --path . --script res://scripts/dev/native_resolution_probe.gd -- --test-defaults
func _initialize() -> void: _run.call_deferred()
func report(label: String, image: Image) -> void:
	print("NATIVE_RES ",label," ",image.get_width(),"x",image.get_height())
func _run() -> void:
	var out := "res://logs/native-resolution"
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(2560,1440)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.test_mode=true
	app.profile.path="user://native-res-%d/profile.json"%OS.get_process_id()
	root.add_child(app)
	AudioServer.set_bus_mute(0,true)
	print("NATIVE_RES window_scale ",RallyNativeResolution.scale_for(app.ui))
	app.show_garage()
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	report("garage_view",app.garage_view.viewport.get_texture().get_image())
	print("NATIVE_RES garage_logical ",app.garage_view.size)
	root.get_texture().get_image().save_png(out+"/garage.png")
	app.start_benchmark()
	while not is_instance_valid(app.showcase) or not app.showcase.ready_to_play: await process_frame
	for i in range(300): await process_frame
	await RenderingServer.frame_post_draw
	var world: RallyShowcaseWorld=app.showcase.worlds[app.showcase.active_world]
	report("showcase_viewport",world.viewport.get_texture().get_image())
	print("NATIVE_RES showcase_aa msaa=",world.viewport.msaa_3d," fxaa=",world.viewport.screen_space_aa==Viewport.SCREEN_SPACE_AA_FXAA)
	root.get_texture().get_image().save_png(out+"/showcase.png")
	quit()

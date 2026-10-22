extends "res://tests/test_suite.gd"
# Off-screen 3D views must render in real window pixels, not the 1280x720
# logical UI canvas, so Retina and large windows stay sharp.
func _run() -> void:
	root.size=Vector2i(2560,1440)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.test_mode=true
	app.profile.path="user://native-res-test-%d/profile.json"%OS.get_process_id()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	await ticks(2)
	var factor := RallyNativeResolution.scale_for(app.ui)
	check(is_equal_approx(factor,2.0),"A 2560x1440 window scales the logical UI by 2 (got %.2f)"%factor)
	app.show_garage()
	await ticks(4)
	var garage: RallyGarageView=app.garage_view
	var expected := Vector2i((garage.size*factor).round())
	check(garage.viewport.size==expected,"Garage 3D view renders at real pixels %s (logical %s, got %s)"%[expected,garage.size,garage.viewport.size])
	# Shelf picking maps logical mouse positions into the pixel viewport.
	var centre := garage.size*.5
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=centre
	var origin := garage.camera.project_ray_origin(centre*Vector2(garage.viewport.size)/garage.size)
	check(origin.is_finite(),"Garage ray projection uses viewport pixels")
	root.size=Vector2i(1920,1080)
	await ticks(4)
	check(garage.viewport.size==Vector2i((garage.size*RallyNativeResolution.scale_for(garage)).round()),"Garage follows window resize (%s)"%garage.viewport.size)
	root.size=Vector2i(2560,1440)
	await ticks(2)
	await app.start_benchmark()
	var demo: RallyShowcaseDirector=app.showcase
	check(is_instance_valid(demo),"Showcase prepared")
	if is_instance_valid(demo):
		demo.set_process(false)
		for world: RallyShowcaseWorld in demo.worlds.values():
			check(world.viewport.size==Vector2i(2560,1440),"Showcase %s renders at the window's real pixels (got %s)"%[world.scene.challenge.stage.stage_id,world.viewport.size])
			check(world.viewport.screen_space_aa==Viewport.SCREEN_SPACE_AA_FXAA and world.viewport.msaa_3d==Viewport.MSAA_DISABLED,"Showcase anti-aliasing matches live driving")
		root.size=Vector2i(1920,1080)
		await ticks(3)
		check(demo.worlds.values()[0].viewport.size==Vector2i(1920,1080),"Showcase follows window resize")
	var helicopter := RallyBroadcastHelicopter.new()
	check(helicopter.camera_viewport==null,"Helicopter builds its camera lazily")
	helicopter.free()
	var source := FileAccess.get_file_as_string("res://scripts/presentation/broadcast_helicopter.gd")
	check("Vector2i(1920,1080)" in source,"Aerial album photos are Full HD")
	finish()

extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://world-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="BRUSHLINE"
	AudioServer.set_bus_mute(0,true)
	await app.start_race()
	var scene: Node3D=app.race
	paused=true
	scene.set_process(false)
	scene.game_hud.hide()
	await process_frame
	scene.pause_menu.hide()
	var route: RallyStageRoute=scene.generator.route
	scene.camera.position=route.position_at(2)+Vector3.UP*2.8
	scene.camera.look_at(route.position_at(20)+Vector3.UP*3.4)
	await shot("start-arch")
	scene.session.phase=RallyStageSession.Phase.RUNNING
	scene.session.progress=route.length*.17
	scene.broadcast.advance(4)
	scene.game_hud.refresh(RallyHUD.data_for(scene.vehicle,scene.session,false))
	scene.game_hud.show()
	await shot("news-chase")
	scene.game_hud.hide()
	var aircraft: Node3D=scene.broadcast.airframe
	scene.camera.position=aircraft.to_global(Vector3(-11,1.5,8))
	scene.camera.look_at(aircraft.to_global(Vector3(-.6,0,.7)))
	await shot("news-camera")
	scene.broadcast.airframe.hide()
	# Models on a neutral native 3D review stage; separate from race-event capture below.
	scene.presentation.environment.fog_enabled=false
	var review := Node3D.new()
	root.add_child(review)
	review.position=Vector3(0,5000,0)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size=Vector2(40,20)
	floor_mesh.mesh=plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color("8e9b83")
	floor_mesh.material_override=mat
	review.add_child(floor_mesh)
	var fill := DirectionalLight3D.new()
	fill.rotation=Vector3(-.6,-.4,0)
	fill.light_energy=1.1
	review.add_child(fill)
	var animals: Array[Node3D]=[]
	for i: int in range(5):
		var model := RallyWildlifeModel.build(RallyWildlifeModel.KINDS[i])
		review.add_child(model)
		model.position=Vector3((i-2)*3.3,0,0)
		model.rotation.y=PI-.6
		animals.append(model)
	scene.camera.position=review.position+Vector3(0,3.8,14)
	scene.camera.look_at(review.position+Vector3.UP*1.2)
	await shot("wildlife-lineup")
	animals[4].position.y=RallyWildlife.hop_height(.425)
	scene.camera.position=review.position+Vector3(10,2,5)
	scene.camera.look_at(animals[4].global_position+Vector3.UP*1.1)
	await shot("kangaroo-hop")
	review.free()
	scene.presentation.environment.fog_enabled=true
	scene.wildlife.events[0].kind="zebra"
	scene.session.progress=scene.wildlife.events[0].s-100
	scene.wildlife.advance(8.8)
	var at: Vector3=scene.wildlife.deer.position
	scene.camera.position=at+Vector3(8,3,9)
	scene.camera.look_at(at+Vector3.UP*1.2)
	await shot("wildlife-crossing")
	await app.leave_race()
	app.free()
	await process_frame
	print("WORLD DETAILS CAPTURE PASSED")
	quit()
func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/world-"+title+".jpg",.95)
	print("SAVED ",title)

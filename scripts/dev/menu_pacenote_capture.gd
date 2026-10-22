extends SceneTree
var app: RallyGameApp
var output := "res://docs/validation/menu-loading-polish"
func _initialize() -> void: _run.call_deferred()
func capture(label: String) -> void:
	for i: int in range(20):
		paused=false
		if is_instance_valid(app.race):
			app.race.controls.resume()
			app.race.pause_menu.hide()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output+"/"+label+".jpg",.94)
	print("CAPTURE ",label)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://menu-note-capture-%d/profile.json"%OS.get_process_id()
	root.add_child(app)
	AudioServer.set_bus_mute(0,true)
	await capture("home-720")
	root.size=Vector2i(1920,1080)
	await capture("home-1080")
	root.size=Vector2i(1280,720)
	app.practice=true
	await app.start_race()
	for i: int in range(30):
		paused=false
		app.race.controls.resume()
		app.race.pause_menu.hide()
		await process_frame
	app.race.vehicle.freeze=true
	app.race.set_process(false)
	app.race.set_physics_process(false)
	for code: String in ["RIGHT_1","LEFT_2","LEFT_3","RIGHT_4","RIGHT_5","LEFT_6"]:
		var data := RallyHUD.data_for(app.race.vehicle,app.race.session,false)
		data["note"]=code
		data["note_distance"]=85.0
		data["bend_degrees"]=[170.0,130.0,90.0,60.0,40.0,20.0][code.get_slice("_",1).to_int()-1]
		data["phase"]=RallyStageSession.Phase.RUNNING
		data["speed"]=85.0
		app.race.game_hud.refresh(data)
		await capture(code.to_lower())
	app.queue_free()
	await process_frame
	quit()

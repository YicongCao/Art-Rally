extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1920,1080)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.test_mode=true
	app.profile.path="user://render-cost-%d/profile.json"%OS.get_process_id()
	root.add_child(app)
	AudioServer.set_bus_mute(0,true)
	app.practice=true
	app.chosen_vehicle="P7"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--stage="): app.chosen_stage=a.trim_prefix("--stage=")
	await app.start_race()
	paused=false
	app.race.set_physics_process(false)
	app.race.vehicle.freeze=true
	var route: RallyStageRoute=app.race.generator.route
	var draws:=0.0
	var prims:=0.0
	var worst_draw:=0
	var worst_prim:=0
	var count:=0
	for i: int in range(16):
		var s:=route.length*(.03+.06*i)
		var pose:=route.pose_at(s,0)
		app.race.vehicle.global_transform=pose
		app.race.camera.global_position=pose*Vector3(0,2.7,7.8)
		app.race.camera.look_at(route.position_at(s+35)+Vector3.UP)
		for f: int in range(6):
			paused=false
			app.race.controls.resume()
			app.race.pause_menu.hide()
			await process_frame
		var d:=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var p:=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		draws+=d;prims+=p;count+=1
		worst_draw=maxi(worst_draw,d);worst_prim=maxi(worst_prim,p)
	print("RENDER_COST: ",JSON.stringify({"stage":app.chosen_stage,"draws_mean":draws/count,"draws_max":worst_draw,"prims_mean":prims/count,"prims_max":worst_prim}))
	await app.leave_race()
	quit()

extends SceneTree
var app: RallyGameApp
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://experience-capture-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="ART RALLY"
	AudioServer.set_bus_mute(0,true)
	app.show_settings()
	await create_timer(.4).timeout
	var categories: RallySettingsPanel=app.ui.find_children("*","RallySettingsPanel",true,false)[0]
	categories.select(2)
	await shot("settings")
	await app.start_race()
	var scene: Node3D=app.race
	scene._set_autopilot_mode_name("vgamepad")
	for i: int in range(1800): await physics_frame
	var data: Dictionary=RallyHUD.data_for(scene.vehicle,scene.session,false)
	data.gate_times=[0.0,8.35]
	data.best_gate_times=[0.0,8.89]
	data.ghost_position=Vector2(scene.vehicle.position.x+8,scene.vehicle.position.z-18)
	data.ghost_progress=scene.session.progress+20
	data.show_fps=true
	scene.game_hud.seen_gates = 0
	scene.game_hud.refresh(data)
	scene.set_process(false)
	scene.game_hud.sector_clock=1.0
	await shot("sector")
	var time: float=scene.session.total_time()
	scene.trajectory.capture(time,scene.vehicle,true)
	scene.session.phase=RallyStageSession.Phase.FINISHED
	app.show_results({"elapsed":time,"penalty":0,"total_time":time,"splits":[time/3,time*2/3,time],"outcome":{"eligible":false}})
	app._set_immersive(true)
	scene.replay.set_camera(0)
	await create_timer(2.5).timeout
	await shot("replay-dust")
	var replay=scene.replay
	print("REPLAY FX: marks=",replay.surface_fx.marks.count," emitting=",replay.surface_fx.particles.filter(func(e: Dictionary): return e.emitter.emitting).size()," side=",replay.broadcast_side)
	scene.replay.playing=false
	scene.replay.set_process(false)
	scene.replay.actor.hide()
	app.immersive_ui.hide()
	scene.wildlife.reset()
	scene.session.phase=RallyStageSession.Phase.RUNNING
	scene.session.progress=scene.wildlife.events[0].s-100
	scene.wildlife.advance(3.0)
	var deer: Vector3=scene.wildlife.deer.position
	scene.camera.position=deer+Vector3(5,2.5,6)
	scene.camera.look_at(deer+Vector3.UP*1.2)
	await shot("reindeer")
	await app.leave_race()
	app.chosen_stage="sunlit_cape"
	await app.start_race()
	scene=app.race
	paused=true
	scene.set_process(false)
	scene.game_hud.hide()
	scene.presentation.sky_life.advance(0)
	var flock: Vector3=Vector3.ZERO
	for i: int in range(5): flock+=scene.presentation.sky_life.birds[i].node.position/5
	scene.camera.position=flock+Vector3(4,-4,33)
	scene.camera.look_at(flock)
	await shot("flock")
	await app.leave_race()
	app.free()
	await process_frame
	quit()
func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/experience-"+title+".jpg",.94)
	print("SAVED ",title)

extends SceneTree

var scene: Node3D
var hint: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--no-vsync" in OS.get_cmdline_user_args(): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	var station := 493.0
	var mode := 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--at="): station = float(argument.trim_prefix("--at="))
		if argument.begins_with("--camera="): mode = int(argument.trim_prefix("--camera="))
	scene.preferences.reset()
	scene.preferences.set_value("volume",0)
	scene.preferences.set_value("low_detail","--low-detail" in OS.get_cmdline_user_args())
	scene.preferences.set_value("tire_visual_gain",2.0 if "--tire-visual-2x" in OS.get_cmdline_user_args() else 1.0)
	scene._apply_preferences()
	if "--compliant" in OS.get_cmdline_user_args(): scene.vehicle.config.tire_contact_model = "COMPLIANT_PATCH"
	if "--no-batches" in OS.get_cmdline_user_args():
		for batch: MultiMeshInstance3D in scene.presentation.scenery.all_batches: batch.visible = false
	if "--no-checkpoints" in OS.get_cmdline_user_args(): scene.presentation.checkpoints.root.visible = false
	if "--no-shadows" in OS.get_cmdline_user_args(): scene.get_node("Sun").shadow_enabled = false
	if "--no-ssao" in OS.get_cmdline_user_args(): scene.presentation.environment.ssao_enabled = false
	if "--msaa2" in OS.get_cmdline_user_args(): root.msaa_3d = Viewport.MSAA_2X
	if "--no-ui" in OS.get_cmdline_user_args():
		scene.game_hud.visible = false
		scene.set_process(false)
	if "--no-dressing" in OS.get_cmdline_user_args(): scene.presentation.scenery.dressing.visible = false
	if "--no-generator-props" in OS.get_cmdline_user_args():
		for child: Node in scene.generator.get_children():
			if child is MeshInstance3D:
				var visual := child as MeshInstance3D
				if visual in scene.generator.road_visuals or visual in scene.generator.water_visuals: continue
			if child is Node3D and child is not StaticBody3D: child.visible = false
	scene.camera_mode = mode
	scene.session.phase = RallyStageSession.Phase.RUNNING
	scene.session.countdown = 0
	scene.session.next_gate = clampi(int((station-20)/100)+1,1,scene.session.gates.size()-1)
	scene.session.progress = station
	scene.session.elapsed = 123.456
	scene.session.previous = scene.generator.route.pose_at(station).origin
	scene.session.projection_hint = scene.generator.route.index_at(station)
	scene.vehicle.request_reset(scene.generator.route.pose_at(station))
	for i: int in range(240):
		paused = false
		scene.pause_menu.show_menu(false)
		await physics_frame
	if "--moving" in OS.get_cmdline_user_args():
		hint = scene.generator.route.index_at(station)
		scene.vehicle.command_source = driver
		for i: int in range(480):
			paused = false
			await physics_frame
	if "--menu" in OS.get_cmdline_user_args(): scene._safety_pause()
	for i: int in range(30): await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "_menu" if "--menu" in OS.get_cmdline_user_args() else ""
	var path := "res://logs/m5_%d_camera%d%s.png"%[station,mode,suffix]
	root.get_texture().get_image().save_png(path)
	print("M5 capture: ",path)
	print("M5 render metrics: fps=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	quit()


func driver(speed: float,_dt: float) -> DriverCommand:
	var command := DriverCommand.new()
	var route: RallyStageRoute = scene.generator.route
	var p := route.project(scene.vehicle.position,hint)
	hint = p.index
	var local: Vector3 = scene.vehicle.to_local(route.position_at(p.s+7))
	command.steer = clampf(atan2(5.2*sin(atan2(local.x,-local.z)),7)/0.55,-1,1)
	command.throttle = clampf((10-speed)*0.3+0.25,0,0.8)
	command.brake = clampf((speed-11)*0.3,0,0.6)
	return command

extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://rockfall-roll-capture/profile.json";root.add_child(app)
	app.practice=true;app.chosen_stage="misty_highlands"
	AudioServer.set_bus_mute(0,true)
	await app.start_race()
	var race: Node3D=app.race
	race.set_process(false);race.vehicle.freeze=true;race.controls.resume();race.pause_menu.hide();race.game_hud.get_parent().hide()
	var pose: Transform3D=race.generator.route.pose_at(900)
	race.vehicle.global_transform=pose;race.vehicle.global_position+=Vector3.UP*.6
	race.vehicle.linear_velocity=-pose.basis.z*18
	race.session.phase=RallyStageSession.Phase.RUNNING;race.session.progress=900
	race.rockfall.reset()
	var camera := Camera3D.new();race.add_child(camera);camera.far=4000
	camera.position=pose.origin+pose.basis.x*48+pose.basis.z*30+Vector3.UP*15
	camera.look_at(pose.origin+pose.basis.x*9-Vector3.UP*9);camera.current=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/rockfall-roll-frames"))
	for frame: int in range(330):
		race.rockfall.advance(1.0/30)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("res://logs/rockfall-roll-frames/%03d.jpg"%frame,.86)
	await app.leave_race();app.free();await process_frame;quit()

extends SceneTree
var app: RallyGameApp
func _initialize() -> void: _run.call_deferred()
func snap(path: String) -> void:
	for frame: int in range(20):
		paused=false
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/brushline/pressure-checkpoint/"+path+".jpg",.94)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/brushline/pressure-checkpoint"))
	root.size=Vector2i(1600,900)
	DisplayServer.window_set_size(root.size)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://pressure-checkpoint-capture/profile.json"
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="BRUSHLINE"
	app.practice=true
	AudioServer.set_bus_mute(0,true)
	for id: String in RallyContentCatalog.STAGES:
		app.chosen_stage=id
		await app.start_race()
		var scene: Node3D=app.race
		var gate := 4
		var station: float=scene.session.gates[gate]
		var route: RallyStageRoute=scene.generator.route
		var pose := route.pose_at(station,0)
		scene.session.next_gate=gate
		scene.vehicle.request_reset(route.pose_at(station-9))
		scene.controls.resume()
		scene.pause_menu.hide()
		scene.game_hud.get_parent().hide()
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.far=4000
		camera.position=pose.origin+pose.basis.z*14-pose.basis.x*1+Vector3.UP*4.2
		camera.look_at(pose.origin+Vector3.UP*1.5)
		camera.current=true
		await snap(id)
		if id=="sunset_ridge":
			var markers: RallyCheckpointMarkers=scene.presentation.checkpoints
			var stand := markers.column_poses[markers.column_gate_indices[gate]]
			camera.position=stand*Vector3(-2.3,2.6,5)
			camera.look_at(stand*Vector3(.25,1.5,-.15))
			await snap("pressure-gate-detail")
		await app.leave_race()
	app.free()
	await process_frame
	quit()

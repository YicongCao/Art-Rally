extends SceneTree
var app: RallyGameApp
const OUT := "res://docs/brushline/scene-refresh/"
func _initialize() -> void: run.call_deferred()
func snap(name_id: String) -> Image:
	for i: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	pixels.save_jpg(OUT+name_id+".jpg",.93)
	return pixels
func run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://scene-refresh-capture/profile.json"
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh();app.profile.data.plate="BRUSHLINE"
	app.prefs.values.reduced_motion=true
	app.practice=true
	AudioServer.set_bus_mute(0,true)
	for pixels: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=pixels;DisplayServer.window_set_size(pixels)
		app._loading_page()
		await snap("loading-%d"%pixels.y)
	root.size=Vector2i(1600,900);DisplayServer.window_set_size(root.size)
	for id: String in RallyContentCatalog.STAGES:
		app.chosen_stage=id
		await app.start_race()
		var race: Node3D=app.race
		paused=false;race.controls.resume();race.pause_menu.hide()
		race.game_hud.get_parent().hide()
		var station: float=race.presentation.sky_life.flocks[0].station
		var route: RallyStageRoute=race.generator.route
		race.session.phase=RallyStageSession.Phase.RUNNING
		race.vehicle.request_reset(route.pose_at(station-40))
		await physics_frame;await physics_frame
		race.vehicle.freeze=true
		race.session.next_gate=1
		while race.session.next_gate<race.session.gates.size()-1 and race.session.gates[race.session.next_gate]<station: race.session.next_gate+=1
		race.session.progress=station-40
		race.session.projection_hint=route.index_at(station-40)
		race.auto_driver.reset_navigation(route,race.vehicle.position)
		var pose := route.pose_at(station-40,0)
		var camera := Camera3D.new();race.add_child(camera)
		camera.far=6000;camera.fov=65
		camera.position=pose.origin+pose.basis.z*8+Vector3.UP*3.8
		camera.look_at(route.position_at(station+10)+Vector3.UP*12)
		camera.current=true
		race.presentation.sky_life.advance(6,station-40)
		await snap(id+"-birds")
		var flock: Dictionary=race.presentation.sky_life.flocks[0]
		print("BIRD ",id," station ",station," time ",flock.time," from ",flock.from," to ",flock.to," camera ",camera.position)
		for bird: Dictionary in flock.birds: print("BIRD_NODE ",bird.node.visible," ",bird.node.position," screen ",camera.unproject_position(bird.node.position)," behind ",camera.is_position_behind(bird.node.position))
		# Keep identical camera and simulation state for the road-material A/B.
		if id=="sunset_ridge":
			camera.position=pose.origin+Vector3.UP*2-pose.basis.z*5
			camera.look_at(pose.origin-pose.basis.z*13)
			paused=true
			await snap("road-wear-on")
			var material: ShaderMaterial=race.generator.road_visuals[0].material_override
			material.set_shader_parameter("wear_strength",0)
			await snap("road-wear-off")
			material.set_shader_parameter("wear_strength",.48)
			paused=false
		var gates: RallyCheckpointMarkers=race.presentation.checkpoints
		var stand := gates.column_poses[gates.column_gate_indices[4]]
		camera.position=stand*Vector3(-2.3,2.4,5)
		camera.look_at(stand*Vector3(.25,1.6,-.15))
		if id=="sunset_ridge":
			await snap("pressure-inflated-a")
			gates.advance(.55,camera.position)
			await snap("pressure-inflated-b")
			race.set_process(false)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/pressure-motion"))
			for frame: int in range(90):
				gates.advance(1.0/30,camera.position)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg("res://logs/pressure-motion/%03d.jpg"%frame,.93)
			race.set_process(true)
		if id=="misty_highlands":
			var bank := route.pose_at(900,0)
			camera.position=bank.origin+bank.basis.x*2+bank.basis.z*9+Vector3.UP*2.5
			camera.look_at(bank.origin-bank.basis.x*5+Vector3.UP*2)
			await snap("highland-mountain-bank")
		await app.leave_race()
	app.free();await process_frame;quit()

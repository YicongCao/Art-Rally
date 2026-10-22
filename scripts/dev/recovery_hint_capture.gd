extends SceneTree

# Native HUD layout fixtures over a live stage, with an immobilized car.
# Uses --test-defaults and never loads or writes the player's profile.
var scene: Node3D
var output := "res://docs/validation/recovery-hints"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	AudioServer.set_bus_mute(0,true)
	for i: int in range(90):
		paused=false
		scene.controls.resume()
		scene.pause_menu.hide()
		await process_frame
	scene.vehicle.freeze=true
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.vehicle.command.throttle=1
	scene.vehicle.command.brake=0
	scene.session.phase=RallyStageSession.Phase.RUNNING
	for i: int in range(510): scene._physics_process(1.0/120)
	for item: Array in [["keyboard-720",Vector2i(1280,720),false,{},true],["gamepad-1080",Vector2i(1920,1080),true,{},true],["rebound-ultrawide",Vector2i(1600,672),false,{str(KEY_R):KEY_BACKSPACE},true],["controls-720",Vector2i(1280,720),false,{},false]]:
		root.size=item[1]
		# Exercise full-width HUD layout instead of the default 16:9 letterbox.
		root.content_scale_size=item[1]
		var data := RallyHUD.data_for(scene.vehicle,scene.session,false)
		data["speed"]=0.0
		data["control_hints"]=RallyHUD.control_hints(item[3],item[2])
		data["recovery_hint"]=item[4]
		data["recovery_reason"]=scene.recovery_advice.reason
		data["recovery_penalty"]=5
		data["warning"]=""
		scene.game_hud.refresh(data)
		for frame: int in range(30):
			paused=false
			scene.pause_menu.hide()
			await process_frame
		await RenderingServer.frame_post_draw
		var captured := root.get_texture().get_image()
		if (Vector2(captured.get_size())-Vector2(item[1])).length()>4:
			push_error("Capture size mismatch: %s"%captured.get_size())
			quit(1)
			return
		captured.save_jpg(output+"/"+str(item[0])+".jpg",.92)
		print("CAPTURE ",item[0]," ",captured.get_size())
	scene.queue_free()
	await process_frame
	quit()

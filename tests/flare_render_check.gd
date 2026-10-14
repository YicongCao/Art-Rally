extends "res://tests/test_suite.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "GPU flare occlusion test requires a real rendering window")
		finish()
		return
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08,0.10,0.12)
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.current = true
	world.add_child(camera)
	var flare := RallySampleFlare.new()
	flare.build(camera)
	var direction := Vector3(0.4,0.25,-1).normalized()
	flare.update(camera,direction,false,1)
	var baseline := await capture()
	flare.update(camera,direction,true,1)
	print("FLARE STATE: uv=",flare.screen_sun," strength=",flare.current_strength," visible=",flare.overlay.visible)
	var clear := await capture()
	var open_delta := difference(baseline,clear)
	var blocker := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.7,0.7)
	blocker.mesh = mesh
	blocker.position = direction*4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.08,0.10,0.12)
	blocker.material_override = material
	world.add_child(blocker)
	var blocked := await capture()
	flare.enabled = false
	flare.update(camera,direction,true,1)
	var blocked_baseline := await capture()
	var blocked_delta := difference(blocked_baseline,blocked)
	blocker.position.x += 0.35
	var partial_baseline := await capture()
	flare.enabled = true
	flare.update(camera,direction,true,1)
	var partial := await capture()
	var partial_delta := difference(partial_baseline,partial)
	check(open_delta > 0.0005, "Unoccluded visible sun renders lens ghosts")
	check(blocked_delta < maxf(open_delta * 0.05,0.00002), "Opaque render geometry without physics collider hides solar ghosts")
	check(partial_delta > open_delta*0.15 and partial_delta < open_delta*0.85, "Partial solar occlusion smoothly reduces the ghost contribution")
	flare.enabled = true
	flare.update(camera,-direction,true,1)
	check(not flare.overlay.visible, "Sun behind camera never renders flare")
	print("FLARE GPU METRICS: open_delta=",open_delta," blocked_delta=",blocked_delta," partial_delta=",partial_delta)
	DirAccess.make_dir_recursive_absolute("res://logs")
	clear.save_png("res://logs/flare_gpu_open.png")
	blocked.save_png("res://logs/flare_gpu_blocked.png")
	world.queue_free()
	await process_frame
	finish()


func capture() -> Image:
	for i: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func difference(a: Image,b: Image) -> float:
	var sum := 0.0
	var count := 0
	# The lower half contains ghosts but not the upper-right test blocker.
	for y: int in range(a.get_height()/2,a.get_height(),3):
		for x: int in range(0,a.get_width(),3):
			var ca := a.get_pixel(x,y)
			var cb := b.get_pixel(x,y)
			sum += absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)
			count += 3
	return sum/maxi(count,1)

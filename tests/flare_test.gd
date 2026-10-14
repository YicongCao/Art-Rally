extends "res://tests/test_suite.gd"


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	var flare := RallySampleFlare.new()
	flare.build(camera)
	var direction := Vector3(0.3,0.2,-1).normalized()
	flare.update(camera,direction,true,1)
	check(flare.current_strength > 0.5 and flare.overlay.visible, "Flare activates only when light projects near viewing direction")
	var first := flare.screen_sun
	camera.rotate_y(0.10)
	flare.update(camera,direction,true,1)
	check(flare.screen_sun.distance_to(first) > 0.02, "Projected solar position follows camera rotation rather than fixed screen art")
	flare.update(camera,-direction,true,1)
	check(not flare.overlay.visible, "Rear-facing sun fades flare to zero")
	flare.update(camera,Vector3(1,0,-0.2).normalized(),true,1)
	check(not flare.overlay.visible, "Off-axis light cannot produce ghosts")
	flare.enabled = false
	flare.update(camera,direction,true,1)
	check(not flare.overlay.visible, "Lens flare can be disabled independently")
	flare.enabled = true
	flare.update(camera,direction,false,1)
	check(not flare.overlay.visible, "Graybox comparison removes optical overlay")
	world.queue_free()
	await process_frame
	finish()

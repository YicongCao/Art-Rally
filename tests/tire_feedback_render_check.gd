extends "res://tests/test_suite.gd"


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"Tire deformation presentation requires a real render window")
		finish()
		return
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.preferences.set_value("volume",0)
	scene.preferences.set_value("tire_visual_gain",2.0)
	scene._apply_preferences()
	scene.vehicle.config.tire_contact_model = "COMPLIANT_PATCH"
	scene.vehicle.request_reset(scene.generator.route.pose_at(493))
	scene.debug_panel.set_enabled(true)
	for i: int in range(240):
		paused = false
		scene.controls.resume()
		scene.pause_menu.show_menu(false)
		await process_frame
	var wheel: Dictionary = scene.debug_panel.model.wheels[0]
	check(wheel.deflection_mm>0 and wheel.patch_length_mm>0 and wheel.patch_samples>=5,"Rendered F9 panel receives live compliant tire and patch data")
	var tire_visual := scene.vehicle.wheel_visuals[0].get_child(0) as MeshInstance3D
	var scale := tire_visual.basis.get_scale()
	check(scale.x<1.0 and scale.z>1.0,"Rendered tire mesh squashes vertically and expands longitudinally from physical state")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/v02_tire_debug.png")
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	finish()

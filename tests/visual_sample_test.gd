extends "res://tests/test_suite.gd"


func _run() -> void:
	var scene: Node3D = load("res://scenes/dev/visual_sample.tscn").instantiate()
	root.add_child(scene)
	await ticks(240)
	var land: RallySampleLandscape = scene.landscape
	check(RallySampleLandscape.END-RallySampleLandscape.START == 200, "Visual sample scope is 200 meters")
	check(land.chunk_bodies.size() < 12, "Full stage is not generated or dressed in sample")
	var reference := RallyStageGenerator.new()
	reference.route.build(land.definition)
	var identical := true
	for i: int in range(land.route.index_at(430),land.route.index_at(630)):
		for col: int in range(9): identical = identical and land.vertex_at(i,col).is_equal_approx(reference.vertex_at(i,col))
	check(identical, "Road geometry exactly matches approved M4 route")
	reference.free()
	check(scene.vehicle.mass == 1250 and scene.vehicle.wheels[0].grounded, "Baseline vehicle remains supported on sample road")
	land.set_style(false)
	check(not land.dressing.visible and land.chunk_bodies[0].collision_layer == 1, "A/B toggle changes presentation without disabling contact")
	land.set_style(true)
	check(land.terrain_bounds.size.x > 900, "Background terrain fills horizon rather than a floating road ribbon")
	scene.queue_free()
	await process_frame
	finish()

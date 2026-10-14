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
	check(scene.scenery.placements.size() > 4000 and scene.scenery.animated_arms.size() == 7, "Sample contains batched vegetation rocks and seven simple spectators")
	var scoped := true
	var clear_road := true
	for item: Dictionary in scene.scenery.placements:
		scoped = scoped and item.s >= land.START and item.s <= land.END
		clear_road = clear_road and absf(item.lateral) >= 3
	check(scoped and clear_road, "Decoration stays within approved sample and outside driving lane")
	check(land.dressing.find_children("*","CollisionObject3D",true,false).is_empty(), "Visual dressing introduces no hidden physics obstacles")
	scene.set_style(false)
	check(not scene.car_style.body.visible and scene.vehicle.get_node("Body").visible, "Graybox mode restores original car presentation")
	scene.set_style(true)
	check(scene.car_style.body.visible and not scene.vehicle.get_node("Body").visible, "Styled body is opt-in and does not replace baseline asset")
	check(scene.vehicle.config.resource_path.is_empty() and not load("res://resources/vehicles/baseline.tres").contact_envelope, "Sample uses local vehicle resource without mutating shared configuration")
	scene.queue_free()
	await process_frame
	finish()

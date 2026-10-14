extends "res://tests/test_suite.gd"


func _run() -> void:
	var scene: Node3D = load("res://scenes/dev/visual_sample.tscn").instantiate()
	root.add_child(scene)
	await ticks(2)
	var gravel: RallySampleGravel = scene.gravel
	check(gravel.placements.size() > 10000 and gravel.batches.size() == 10, "Aggregate uses dense geometry batched into ten 20m patches")
	var shallow := true
	var scoped := true
	var tracks := 0
	var center := 0
	for sample: Dictionary in gravel.placements:
		shallow = shallow and sample.height <= 0.014 and sample.radius <= 0.055
		scoped = scoped and sample.s >= 430 and sample.s <= 630 and absf(sample.lateral) <= 2.75
		if absf(absf(sample.lateral)-0.8) < 0.28: tracks += 1
		if absf(sample.lateral) < 0.56: center += 1
	check(shallow and scoped, "Only shallow 4-14mm visual gravel is added within the 200m road")
	check(tracks < center*0.5, "Compacted wheel tracks have less loose aggregate than center strip")
	check(gravel.root.find_children("*","CollisionObject3D",true,false).is_empty(), "Micro gravel cannot change tire contact or create rigid obstacles")
	var repeated := RallySampleGravel.new()
	repeated.build(scene.landscape)
	check(repeated.placements == gravel.placements, "Road aggregate placement is deterministic")
	scene.set_style(false)
	check(not gravel.root.is_visible_in_tree(), "Graybox mode hides geometric gravel")
	scene.queue_free()
	await process_frame
	finish()

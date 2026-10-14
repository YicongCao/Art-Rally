extends "res://tests/test_suite.gd"


func _run() -> void:
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	await ticks(480)
	check(scene.session.phase == RallyStageSession.Phase.ARMED, "Playable stage completes countdown")
	check(scene.vehicle.wheels[0].surface.surface_id == 1 and scene.vehicle.config.contact_envelope, "Stage starts on gravel with envelope contact enabled")
	check(scene.vehicle.position.distance_to(scene.generator.route.pose_at(8).origin) < 0.3, "Brake hold keeps starting car stationary on generated slope")
	scene.session.phase = RallyStageSession.Phase.RUNNING
	scene.session.next_gate = 2
	scene._reset()
	scene._reset()
	check(scene.session.penalty == 5, "Repeated reset events within same physics step cannot double charge")
	await ticks(360)
	check(scene.vehicle.position.distance_to(scene.generator.route.pose_at(114).origin) < 0.5 and not scene.respawn_wait, "Deferred recovery settles on last passed checkpoint approach")
	scene._toggle_pause()
	var clock: float = scene.session.elapsed
	await ticks(120)
	check(scene.session.elapsed == clock, "Stage clock freezes while paused")
	scene._restart()
	await ticks(480)
	check(not paused and scene.session.penalty == 0 and scene.session.next_gate == 0, "Restart from pause restores clean stage")
	scene._toggle_mode()
	check(scene.session.practice and scene.session.phase == RallyStageSession.Phase.COUNTDOWN, "Practice toggle restarts instead of editing an active race result")
	scene.queue_free()
	await process_frame
	finish()

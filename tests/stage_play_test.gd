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
	scene.result_store.path = "user://m6_stage_play_%d.cfg"%Time.get_ticks_usec()
	scene.result_persistence_enabled = true
	scene.session.phase = RallyStageSession.Phase.FINISHED
	scene.session.elapsed = 200
	scene.session.penalty = 5
	scene.session.next_gate = scene.session.gates.size()
	scene._record_finish()
	scene._record_finish()
	check(scene.finish_record.new_record and scene.result_summary.human_best.total_time==205 and scene.result_summary.recent.size()==1,"Finish edge saves one human result and refreshes the HUD summary")
	scene._restart()
	await ticks(480)
	check(not paused and scene.session.penalty == 0 and scene.session.next_gate == 0, "Restart from pause restores clean stage")
	scene._toggle_mode()
	check(scene.session.practice and scene.session.phase == RallyStageSession.Phase.COUNTDOWN, "Practice toggle restarts instead of editing an active race result")
	await ticks(120)
	scene.session.phase = RallyStageSession.Phase.FINISHED
	scene.session.next_gate = scene.session.gates.size()
	scene.session.elapsed = 220
	scene.session.progress = scene.session.gates[-1]
	scene._record_finish()
	check(scene.result_summary.recent.size()==1,"Practice completion cannot append a stored result")
	scene.vehicle.request_reset(Transform3D(Basis.IDENTITY, Vector3(0, -100, 0)))
	await ticks(480)
	check(scene.session.total_time() == 220 and scene.vehicle.position.y > 0, "Out-of-bounds after finish preserves result and restores safe finish pose")
	DirAccess.remove_absolute(scene.result_store.path)
	scene.queue_free()
	await process_frame
	finish()

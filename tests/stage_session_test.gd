extends "res://tests/test_suite.gd"


func _run() -> void:
	var route := RallyStageRoute.new()
	route.build(load("res://resources/stages/sunset_ridge.tres"))
	var session := RallyStageSession.new()
	session.setup(route)
	session.step(route.pose_at(8).origin, 0, 3.1)
	check(session.phase == RallyStageSession.Phase.ARMED and session.elapsed == 0, "Countdown arms start without starting race clock")
	cross_gate(session, 20, true)
	check(session.next_gate == 0, "Reverse crossing does not start stage")
	cross_gate(session, 20)
	check(session.phase == RallyStageSession.Phase.RUNNING and session.next_gate == 1, "Forward start crossing begins timing")
	cross_gate(session, 220)
	check(session.next_gate == 1, "Skipping a checkpoint cannot advance race order")
	cross_gate(session, 120, false, 10)
	check(session.next_gate == 1, "Crossing outside gate width is rejected")
	cross_gate(session, 120)
	check(session.next_gate == 2, "Expected checkpoint advances after returning to it")
	var elapsed := session.elapsed
	var pose := session.recover()
	check(session.penalty == 5 and session.elapsed == elapsed and session.next_gate == 2, "Recovery adds five seconds without erasing checkpoint order or clock")
	check(route.project(pose.origin).s < 120 and route.project(pose.origin).s > 110, "Recovery lands behind last passed safe gate")
	while session.next_gate < session.gates.size(): cross_gate(session, session.gates[session.next_gate])
	check(session.phase == RallyStageSession.Phase.FINISHED, "All ordered forward gates complete stage")
	var result := session.total_time()
	session.step(pose.origin, 0, 20)
	check(session.total_time() == result, "Finish freezes result")
	session.restart()
	check(session.phase == RallyStageSession.Phase.COUNTDOWN and session.next_gate == 0 and session.penalty == 0, "Restart clears time penalties gates and notes")
	session.setup(route, true)
	session.step(route.pose_at(8).origin, 0, 3.1)
	cross_gate(session, 20)
	session.recover()
	check(session.penalty == 0, "Practice recovery does not receive timed penalty")
	session.phase = RallyStageSession.Phase.RUNNING
	session.next_gate = 12
	session.previous = route.pose_at(1080).origin
	session.step(route.pose_at(1081).origin, 20, 0.1)
	var note_cursor := session.next_note
	session.previous = route.pose_at(1050).origin
	session.step(route.pose_at(1049).origin, 10, 0.1)
	check(note_cursor > 0 and session.next_note == note_cursor, "Reversing never replays consumed pacenotes")
	session.current_note = "WATER"
	session.note_remaining = 5
	session.note_s = 1270
	session.next_gate = 14
	session.projection_hint = route.index_at(1250)
	session.previous = route.pose_at(1250).origin
	session.step(route.pose_at(1251).origin, 40, 0.01)
	check(session.current_note == "WATER", "Active hazard note is not immediately overwritten by a future turn")
	session.restart()
	session.phase = RallyStageSession.Phase.ARMED
	session.previous = route.pose_at(8).origin
	session.step(route.pose_at(100).origin, 50, 0.01)
	check(session.next_gate == 0, "Long teleport across a gate is not credited as physical crossing")
	finish()


func cross_gate(session: RallyStageSession, s: float, backward: bool = false, lateral: float = 0) -> void:
	var route := session.route
	var offset := route.rights[route.index_at(s)] * lateral
	var from := route.pose_at(s + (1 if backward else -1)).origin + offset
	var to := route.pose_at(s + (-1 if backward else 1)).origin + offset
	session.previous = from
	session.step(to, 10, 0.2)

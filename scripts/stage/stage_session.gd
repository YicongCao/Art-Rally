class_name RallyStageSession
extends RefCounted

enum Phase { COUNTDOWN, ARMED, RUNNING, FINISHED }

var route: RallyStageRoute
var phase: Phase = Phase.COUNTDOWN
var countdown: float = 3.0
var elapsed: float = 0.0
var penalty: float = 0.0
var next_gate: int = 0
var gates := PackedFloat64Array()
var previous := Vector3.ZERO
var progress: float = 0.0
var projection: Dictionary = {}
var projection_hint: int = -1
var next_note: int = 0
var current_note: String = ""
var note_remaining: float = 0
var note_s: float = 0
var practice: bool = false
var reset_count: int = 0


func setup(stage_route: RallyStageRoute, free_practice: bool = false) -> void:
	route = stage_route
	practice = free_practice
	gates.clear()
	for s: int in range(20, int(route.length - 60), 100): gates.append(s)
	gates.append(route.length - 30)
	restart()


func restart() -> Transform3D:
	phase = Phase.COUNTDOWN
	countdown = 3.0
	elapsed = 0
	penalty = 0
	next_gate = 0
	next_note = 0
	current_note = ""
	note_remaining = 0
	progress = 8
	reset_count = 0
	var pose := route.pose_at(8)
	previous = pose.origin
	projection_hint = route.index_at(8)
	projection = route.project(previous, projection_hint)
	return pose


func step(position: Vector3, speed: float, dt: float) -> void:
	if phase == Phase.FINISHED: return
	if phase == Phase.COUNTDOWN:
		countdown = maxf(0, countdown - dt)
		if countdown <= 0: phase = Phase.ARMED
		previous = position
		return
	if phase == Phase.RUNNING: elapsed += dt
	projection = route.project(position, projection_hint, 45)
	if float(projection.distance) > 30: projection = route.project(position)
	projection_hint = projection.index
	# A gate requires a physical forward crossing, not proximity or projected progress alone.
	if position.distance_to(previous) <= 15 and next_gate < gates.size():
		var s := gates[next_gate]
		var center := route.position_at(s)
		var forward := route.tangent_at(s)
		var before := (previous - center).dot(forward)
		var after := (position - center).dot(forward)
		if before < 0 and after >= 0:
			var at := previous.lerp(position, -before / maxf(after - before, 0.0001))
			var lateral := absf((at - center).dot(route.rights[route.index_at(s)]))
			if lateral <= route.width_at(s) * 0.5 + 0.8 and absf(at.y - center.y) < 3:
				next_gate += 1
				if phase == Phase.ARMED: phase = Phase.RUNNING
				if next_gate == gates.size(): phase = Phase.FINISHED
	progress = clampf(projection.s, 0, gates[mini(next_gate, gates.size() - 1)])
	note_remaining = maxf(0, note_remaining - dt)
	if next_gate > 0 and phase != Phase.FINISHED:
		var lookahead := clampf(speed * 4, 35, 130)
		while next_note < route.notes.size() and float(route.notes[next_note].s) <= progress + lookahead:
			var note: Dictionary = route.notes[next_note]
			if float(note.s) >= progress - 8:
				current_note = note.code
				note_s = note.s
				note_remaining = 5
			next_note += 1
	previous = position


func recover() -> Transform3D:
	if phase == Phase.FINISHED: return route.pose_at(gates[-1] + 5)
	if phase == Phase.RUNNING:
		if not practice: penalty += 5
		reset_count += 1
	var s := 8.0 if next_gate == 0 else maxf(8, gates[next_gate - 1] - 6)
	var pose := route.pose_at(s)
	previous = pose.origin
	projection_hint = route.index_at(s)
	projection = route.project(previous, projection_hint)
	progress = s
	# Keep the note cursor to avoid replaying calls when reversing or recovering.
	current_note = ""
	note_remaining = 0
	return pose


func total_time() -> float:
	return elapsed + penalty


func accepts_input() -> bool:
	return phase in [Phase.ARMED, Phase.RUNNING]

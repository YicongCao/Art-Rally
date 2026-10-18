class_name RallyStageSession
extends RefCounted

signal missed_checkpoint_penalty(start: float, end: float)

enum Phase { COUNTDOWN, ARMED, RUNNING, FINISHED }

var route: RallyStageRoute
var phase: Phase = Phase.COUNTDOWN
var countdown: float = 3.0
var elapsed: float = 0.0
var penalty: float = 0.0
var next_gate: int = 0
var gates := PackedFloat64Array()
var previous := Vector3.ZERO
var previous_basis := Basis.IDENTITY
var progress: float = 0.0
var projection: Dictionary = {}
var projection_hint: int = -1
var next_note: int = 0
var current_note: String = ""
var note_remaining: float = 0
var note_s: float = 0
var practice: bool = false
var reset_count: int = 0
var split_times: Array[float] = []
var gate_times: Array[float] = []
var split_gates: Array[int] = []
var missed_gates: Array[int] = []
var miss_notice_remaining: float = 0


func setup(stage_route: RallyStageRoute, free_practice: bool = false) -> void:
	route = stage_route
	practice = free_practice
	gates.clear()
	for s: int in range(20, int(route.length - 60), 100): gates.append(s)
	gates.append(route.length - 30)
	split_gates.clear()
	for fraction: float in route.definition.split_fractions:
		var nearest := 0
		for i: int in range(gates.size()):
			if absf(gates[i]-fraction*gates[-1])<absf(gates[nearest]-fraction*gates[-1]): nearest = i
		split_gates.append(nearest)
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
	missed_gates.clear()
	miss_notice_remaining = 0
	split_times.clear()
	gate_times.clear()
	var pose := route.pose_at(8)
	previous = pose.origin
	previous_basis = pose.basis
	projection_hint = route.index_at(8)
	projection = route.project(previous, projection_hint)
	return pose


func step(position: Vector3, speed: float, dt: float, body_basis: Basis = Basis.IDENTITY, body_size: Vector3 = Vector3.ZERO) -> void:
	if phase == Phase.FINISHED: return
	miss_notice_remaining = maxf(0,miss_notice_remaining-dt)
	if phase == Phase.COUNTDOWN:
		countdown = maxf(0, countdown - dt)
		if countdown <= 0: phase = Phase.ARMED
		previous = position
		previous_basis = body_basis
		return
	if phase == Phase.RUNNING: elapsed += dt
	projection = route.project(position, projection_hint, 45)
	if float(projection.distance) > 30: projection = route.project(position)
	projection_hint = projection.index
	# Start/finish require a physical crossing; ordinary missed gates cost five seconds.
	# Only continuous forward motion can retire gates, never recovery/teleport or reversing.
	if position.distance_to(previous)<=15:
		while next_gate<gates.size():
			var s := gates[next_gate]
			var center := route.position_at(s)
			var forward := route.tangent_at(s)
			var crossed := _body_crosses(previous,position,previous_basis,body_basis,body_size*.5,center,forward,route.rights[route.index_at(s)],route.width_at(s)*.5+1.09)
			var missed := phase==Phase.RUNNING and next_gate>0 and next_gate<gates.size()-1 and float(projection.s)>s+maxf(4,body_size.length()*.5) and (position-previous).dot(route.tangent_at(projection.s))>.00001
			if not crossed and not missed: break
			if not crossed:
				missed_gates.append(next_gate)
				if not practice:
					penalty += 5
					missed_checkpoint_penalty.emit(total_time()-5,total_time())
				miss_notice_remaining = 2.5
			gate_times.append(total_time())
			if next_gate in split_gates: split_times.append(total_time())
			next_gate += 1
			if phase==Phase.ARMED: phase=Phase.RUNNING
			if next_gate==gates.size(): phase=Phase.FINISHED
	progress = clampf(projection.s, 0, gates[mini(next_gate, gates.size() - 1)])
	note_remaining = maxf(0, note_remaining - dt)
	if next_gate > 0 and phase != Phase.FINISHED:
		var lookahead := clampf(speed * 4, 35, 130)
		while next_note < route.notes.size() and float(route.notes[next_note].s) < progress - 8:
			next_note += 1
		if next_note < route.notes.size() and float(route.notes[next_note].s) <= progress + lookahead and (note_remaining <= 2 or progress > note_s):
			var note: Dictionary = route.notes[next_note]
			current_note = note.code
			note_s = note.s
			note_remaining = 5
			next_note += 1
	previous = position
	previous_basis = body_basis


func recover(penalty_seconds: float = 5.0) -> Transform3D:
	if phase == Phase.FINISHED: return route.pose_at(gates[-1] + 5)
	if phase == Phase.RUNNING or penalty_seconds >= 10:
		if not practice: penalty += maxf(0,penalty_seconds)
		reset_count += 1
	var s := 8.0 if next_gate == 0 else maxf(8, gates[next_gate - 1] - 6)
	var pose := route.pose_at(s)
	previous = pose.origin
	previous_basis = pose.basis
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


static func _body_crosses(from: Vector3,to: Vector3,old_basis: Basis,new_basis: Basis,half: Vector3,center: Vector3,forward: Vector3,right: Vector3,opening: float) -> bool:
	if (to-from).dot(forward)<=.00001: return false
	var reach := half.length()
	var before := (from-center).dot(forward)
	var after := (to-center).dot(forward)
	if maxf(before,after)<-reach or minf(before,after)>reach: return false
	# Intersect the swept OBB corners and the present OBB edges with the gate plane.
	# This credits the first tiny body overlap, including a rotated front corner.
	var old: Array[Vector3] = []
	var now: Array[Vector3] = []
	for i: int in range(8):
		var local := Vector3(half.x*(1 if i&1 else -1),half.y*(1 if i&2 else -1),half.z*(1 if i&4 else -1))
		old.append(from+old_basis*local)
		now.append(to+new_basis*local)
	var hits: Array[Vector3] = []
	for i: int in range(8):
		_plane_hit(old[i],now[i],center,forward,hits)
		for bit: int in [1,2,4]:
			if not i&bit: _plane_hit(now[i],now[i|bit],center,forward,hits)
	var left := INF
	var rightmost := -INF
	for at: Vector3 in hits:
		if absf(at.y-center.y)>3: continue
		var across := (at-center).dot(right)
		left = minf(left,across)
		rightmost = maxf(rightmost,across)
	return left<=opening and rightmost>=-opening


static func _plane_hit(a: Vector3,b: Vector3,center: Vector3,normal: Vector3,hits: Array[Vector3]) -> void:
	var da := (a-center).dot(normal)
	var db := (b-center).dot(normal)
	if absf(da)<.00001: hits.append(a)
	if da*db<=0 and absf(db-da)>.000001: hits.append(a.lerp(b,clampf(-da/(db-da),0,1)))

class_name RallyRecoveryAdvice
extends RefCounted

const BLOCKED_SECONDS := 4.0
const MOVEMENT_RADIUS := 1.5
var blocked_time: float = 0
var overturned_time: float = 0
var wrong_way_time: float = 0
var visible: bool = false
var reason: String = ""
var anchor := Vector3.INF
var blocked_latched := false

func reset() -> void:
	blocked_time=0; overturned_time=0; wrong_way_time=0; visible=false
	reason=""; anchor=Vector3.INF; blocked_latched=false

func update(dt: float,speed: float,upright: float,heading: float,throttle: float,brake: float,enabled: bool,handbrake: float=0,position: Vector3=Vector3.INF,drive_engaged: bool=true) -> bool:
	if not enabled:
		reset()
		return false
	# Measure world-space displacement, not wheel RPM or route progress. A car
	# bouncing against rocks can have velocity without escaping its footprint.
	var located := position.is_finite()
	if located and not anchor.is_finite(): anchor=position
	var moved := located and Vector2(position.x-anchor.x,position.z-anchor.z).length()>MOVEMENT_RADIUS
	if moved or (not located and speed>=.7):
		blocked_time=0
		blocked_latched=false
		anchor=position
	var attempting := throttle>.45 and brake<.2 and handbrake<.1 and drive_engaged
	if attempting and speed<3 and (located or speed<.7):
		blocked_time+=dt
		if blocked_time>=BLOCKED_SECONDS: blocked_latched=true
	elif not blocked_latched:
		blocked_time=0
		anchor=position
	# Keep an established hint when the driver releases the pedal to read it.
	# Genuine displacement, recovery, restart or leaving driving clears it.
	overturned_time=overturned_time+dt if upright<.35 and speed<4 else 0.0
	wrong_way_time=wrong_way_time+dt if heading<-.65 and speed<2 else 0.0
	reason="车辆翻覆" if overturned_time>2 else ("车辆受困" if blocked_latched else ("方向受阻" if wrong_way_time>5 else ""))
	visible=not reason.is_empty()
	return visible

class_name RallyRecoveryAdvice
extends RefCounted

var blocked_time: float = 0
var overturned_time: float = 0
var wrong_way_time: float = 0
var visible: bool = false

func reset() -> void:
	blocked_time=0; overturned_time=0; wrong_way_time=0; visible=false

func update(dt: float,speed: float,upright: float,heading: float,throttle: float,brake: float,enabled: bool) -> bool:
	if not enabled:
		reset()
		return false
	blocked_time=blocked_time+dt if speed<.7 and throttle>.45 and brake<.2 else 0.0
	overturned_time=overturned_time+dt if upright<.35 and speed<4 else 0.0
	wrong_way_time=wrong_way_time+dt if heading<-.65 and speed<2 else 0.0
	visible=blocked_time>4 or overturned_time>2 or wrong_way_time>5
	return visible

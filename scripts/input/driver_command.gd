class_name DriverCommand
extends RefCounted

var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0
var handbrake: float = 0.0
var shift: int = 0


func sanitize() -> void:
	steer = clampf(steer, -1, 1) if is_finite(steer) else 0.0
	throttle = clampf(throttle, 0, 1) if is_finite(throttle) else 0.0
	brake = clampf(brake, 0, 1) if is_finite(brake) else 0.0
	handbrake = clampf(handbrake, 0, 1) if is_finite(handbrake) else 0.0
	shift = clampi(shift, -1, 1)

class_name InputProfile
extends Resource

@export var throttle_rise_seconds: float = 0.30
@export var brake_rise_seconds: float = 0.12
@export var steering_rate: float = 4.0
@export var return_rate: float = 5.0
@export var countersteer_rate: float = 7.0
@export var high_speed_limit: float = 0.20
@export var high_speed_mps: float = 35.0
@export var stick_deadzone: float = 0.12
@export var stick_exponent: float = 1.35


static func light_assist() -> InputProfile:
	var result := InputProfile.new()
	result.high_speed_limit = 0.38
	result.steering_rate = 5.0
	result.throttle_rise_seconds = 0.18
	return result

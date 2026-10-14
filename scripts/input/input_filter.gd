class_name DriverInputFilter
extends RefCounted

var profile: InputProfile = InputProfile.new()
var steering: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0


func reset() -> void:
	steering = 0.0
	throttle = 0.0
	brake = 0.0


func step(raw: DriverCommand, speed: float, dt: float, keyboard: bool) -> DriverCommand:
	raw.sanitize()
	var blend := smoothstep(4.0, profile.high_speed_mps, absf(speed))
	var limit := lerpf(1.0, profile.high_speed_limit if keyboard else 0.65, blend)
	var target := raw.steer * limit
	var rate := lerpf(profile.steering_rate, 1.3, blend) if keyboard else 8.0
	if is_zero_approx(target):
		rate = profile.return_rate
	elif target * steering < 0.0:
		rate = profile.countersteer_rate
	steering = move_toward(steering, target, rate * dt)
	throttle = move_toward(throttle, raw.throttle, dt / (profile.throttle_rise_seconds if keyboard and raw.throttle > throttle else 0.06))
	brake = move_toward(brake, raw.brake, dt / (profile.brake_rise_seconds if keyboard and raw.brake > brake else 0.06))
	var result := DriverCommand.new()
	result.steer = steering
	result.throttle = throttle
	result.brake = brake
	result.handbrake = raw.handbrake
	result.shift = raw.shift
	return result


func stick(value: float) -> float:
	return signf(value) * pow(maxf(0, (absf(value) - profile.stick_deadzone) / (1.0 - profile.stick_deadzone)), profile.stick_exponent)

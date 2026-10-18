class_name RallyReverseAssist
extends RefCounted

const HOLD_SECONDS := 0.6
const STOP_SPEED := 0.30
var held_seconds: float = 0
var reverse_throttle: float = 0
var returning_forward: bool = false


func reset() -> void:
	held_seconds = 0
	reverse_throttle = 0
	returning_forward = false


func remaining() -> float:
	return maxf(0.01,HOLD_SECONDS-held_seconds) if held_seconds>0 else 0.0


func apply(command: DriverCommand,intent: DriverCommand,drive: RallyDrivetrain,speed: float,grounded: bool,dt: float,enabled: bool = true) -> DriverCommand:
	if not enabled:
		reset()
		return command
	if command.shift!=0:
		reset()
		if drive.gear<0: command.throttle = 0
		return command
	returning_forward = false
	if drive.gear<0:
		held_seconds = 0
		if intent.throttle>0.05:
			# First stop using service brakes, then request a mechanically safe direction change.
			returning_forward = true
			reverse_throttle = 0
			command.brake = maxf(0.5,maxf(command.throttle,command.brake))
			command.throttle = 0
			if speed<=STOP_SPEED and grounded and drive.request_shift(1,speed): returning_forward = false
			return command
		if drive.shift_remaining>0:
			command.throttle = 0
			command.brake = 1
			return command
		var target := command.brake if intent.brake>0.05 else 0.0
		reverse_throttle = move_toward(reverse_throttle,target,dt/(0.30 if target>reverse_throttle else 0.06))
		command.throttle = reverse_throttle
		command.brake = 0
		return command
	reverse_throttle = 0
	# The hold gate uses raw intent: releasing the pedal must cancel immediately, not after filtering.
	if intent.brake>0.20 and intent.throttle<=0.05 and intent.handbrake<=0.05 and grounded and speed<=STOP_SPEED:
		held_seconds = minf(held_seconds+dt,HOLD_SECONDS)
		command.throttle = 0
		if held_seconds>=HOLD_SECONDS-0.000001 and drive.request_shift(-1,speed):
			held_seconds = 0
			command.brake = 1
	else: held_seconds = 0
	return command

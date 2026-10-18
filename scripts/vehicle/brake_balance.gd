class_name RallyBrakeBalance
extends RefCounted

# Reserve some combined-friction capacity for steering under trail braking.
# Suspension already supplies real axle load transfer. Never inject a yaw impulse.
static func service_torque(requested: float,wheel: RallyWheelState,front: bool,steer: float,speed: float,layout: String,config: RallyVehicleConfig,tire: RallyTireConfig) -> float:
	if not config.corner_brake_balance or not wheel.grounded: return requested
	var turning := smoothstep(.02,.12,absf(steer))*smoothstep(5,12,speed)
	if turning<=0: return requested
	var grip := RallyTireModel.capacity(wheel.load,tire)*wheel.surface.grip(wheel.longitudinal_speed)
	var reserve: float = .52 if front else {"FWD":.86,"RWD":.78,"AWD":.82}.get(layout,.82)
	# When the rear is already sliding, ease its service brake so it can recover lateral grip.
	if not front: reserve = lerpf(reserve,.55,smoothstep(.12,.30,absf(wheel.slip_angle)))
	var cap := grip*wheel.effective_radius*reserve
	return lerpf(requested,minf(requested,cap),turning)

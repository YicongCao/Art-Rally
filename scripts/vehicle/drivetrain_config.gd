class_name RallyDrivetrainConfig
extends Resource

@export var calibration_version: String = "200ps-v2-patch1"
@export_enum("FWD", "AWD", "RWD") var drive_layout: String = "AWD"
@export var rated_power_ps: float = 200.0
@export var electric: bool = false
@export var regen_torque: float = 85.0
@export var electric_front_share: float = 0.38
@export var power_multiplier: float = 1.0
@export var torque_rpms := PackedFloat64Array([950, 1800, 3000, 4500, 5500, 6500, 7600])
@export var torque_values := PackedFloat64Array([90, 200, 250, 260, 250, 216, 155])

@export var idle_rpm: float = 950
@export var redline_rpm: float = 7600
@export var upshift_rpm: float = 6800
@export var downshift_rpm: float = 2600
@export var downshift_target_rpm: float = 4200
@export var upshift_road_fraction: float = 0.88
@export var max_upshift_slip: float = 0.35
@export var loose_surface_assist: bool = false
@export var engine_inertia: float = 0.32
@export var clutch_capacity: float = 650
@export var clutch_coupling: float = 12
@export var final_drive: float = 4.1
@export var ratios := PackedFloat64Array([3.10, 2.15, 1.62, 1.28, 1.04, 0.87])
@export var reverse_ratio: float = -3.0
@export var shift_seconds: float = 0.16
@export var diff_lock_gain: float = 28
@export var axle_lock_limit: float = 260
@export var center_lock_limit: float = 450


func torque_at(rpm: float) -> float:
	var value: float = torque_values[-1]
	for i: int in range(torque_rpms.size() - 1):
		if rpm <= torque_rpms[i + 1]:
			value = lerpf(torque_values[i], torque_values[i + 1], clampf((rpm - torque_rpms[i]) / (torque_rpms[i + 1] - torque_rpms[i]), 0, 1))
			break
	# PS is metric horsepower; cap interpolated power as well as the curve's control points.
	var power_limit_torque := rated_power_ps * 735.49875 / (maxf(rpm, 1.0) * TAU / 60)
	return maxf(0, minf(value, power_limit_torque))

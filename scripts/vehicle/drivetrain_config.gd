class_name RallyDrivetrainConfig
extends Resource

@export_enum("FWD", "AWD", "RWD") var drive_layout: String = "AWD"

@export var idle_rpm: float = 950
@export var redline_rpm: float = 7600
@export var upshift_rpm: float = 6800
@export var downshift_rpm: float = 2600
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
	var speeds := PackedFloat64Array([950, 2000, 3500, 5000, 6500, 7600])
	var torques := PackedFloat64Array([125, 240, 370, 430, 338, 240])
	for i: int in range(speeds.size() - 1):
		if rpm <= speeds[i + 1]:
			return lerpf(torques[i], torques[i + 1], clampf((rpm - speeds[i]) / (speeds[i + 1] - speeds[i]), 0, 1))
	return torques[-1]

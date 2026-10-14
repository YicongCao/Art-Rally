class_name RallyVehicleConfig
extends Resource

@export var body_mass: float = 1250.0
@export var body_inertia := Vector3(650, 1750, 1850)
@export var center_of_mass := Vector3(0, -0.10, 0)
@export var wheelbase: float = 2.6
@export var track_width: float = 1.6
@export var wheel_radius: float = 0.34
@export var wheel_inertia: float = 1.6
@export var suspension_rest: float = 0.48
@export var suspension_min: float = 0.12
@export var static_compression: float = 0.13
@export var compression_damping: float = 2400.0
@export var rebound_damping: float = 3400.0
@export var bump_stiffness: float = 180000.0
@export var max_steer_radians: float = 0.55
@export var front_brake_bias: float = 0.62
@export var total_brake_torque: float = 6400.0
@export var handbrake_torque: float = 2300.0
@export var drag_coefficient_area: float = 0.85
@export var rolling_resistance: float = 0.015
@export var front_anti_roll: float = 6500.0
@export var rear_anti_roll: float = 4500.0
@export var contact_envelope: bool = false


func spring_rate() -> float:
	return body_mass * 9.81 / 4.0 / static_compression


func wheel_mount(index: int) -> Vector3:
	return Vector3((-1 if index % 2 == 0 else 1) * track_width * 0.5, 0, (-1 if index < 2 else 1) * wheelbase * 0.5)

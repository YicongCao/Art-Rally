class_name RallyTireConfig
extends Resource

@export var friction: float = 1.05
@export var longitudinal_stiffness: float = 12.0
@export var lateral_stiffness: float = 8.0
@export var low_speed_reference: float = 3.0
@export var reference_load: float = 3100.0
@export var load_sensitivity: float = 0.12
@export var sliding_ratio: float = 0.78
@export var relaxation_length: float = 0.30

@export_group("Vertical Compliance")
@export var section_width: float = 0.23
@export var inflation_pressure_pa: float = 210000.0
@export var reference_pressure_pa: float = 210000.0
@export var radial_stiffness: float = 180000.0
@export var radial_pressure_gain: float = 0.45
@export var radial_nonlinear_stiffness: float = 1800000.0
@export var radial_damping: float = 120.0
@export var max_radial_deflection: float = 0.055
@export var bottoming_start: float = 0.045
@export var bottoming_stiffness: float = 2500000.0
@export_range(0.0,1.0,0.01) var effective_radius_deflection_ratio: float = 0.65


func vertical_linear_stiffness() -> float:
	var pressure_ratio := inflation_pressure_pa / maxf(reference_pressure_pa,1.0)
	return radial_stiffness*clampf(1.0+radial_pressure_gain*(pressure_ratio-1.0),0.35,2.5)

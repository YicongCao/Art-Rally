class_name RallyTireConfig
extends Resource

@export var friction: float = 1.05
@export var compound: String = "stock"
@export var surface_grip := PackedFloat64Array([1,1,1,1,1,1])

func grip_factor(surface: int) -> float:
	return surface_grip[surface] if surface>=0 and surface<surface_grip.size() else 1.0

func grip_for(sample: RallySurfaceSample) -> float:
	# Stock remains exactly the legacy coefficient; tuned tires interpolate.
	if compound=="stock" or sample.blend_weights.is_empty(): return grip_factor(sample.surface_id)
	var result := 0.0
	for i: int in range(sample.blend_weights.size()): result += sample.blend_weights[i]*grip_factor(i)
	return result

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

@export_group("Contact Patch")
@export var patch_length_scale: float = 0.55
@export var carcass_contact_pressure_pa: float = 20000.0
@export var min_patch_half_length: float = 0.025
@export var max_patch_half_length: float = 0.095
@export var min_patch_half_width: float = 0.055
@export var max_patch_half_width: float = 0.115
@export_range(0.25,2.0,0.05) var patch_pressure_exponent: float = 1.0
@export var contact_height_refine_threshold: float = 0.003
@export var contact_normal_refine_radians: float = 0.07
@export var contact_cluster_tolerance: float = 0.06

@export_group("Patch Brush")
@export var longitudinal_relaxation_length: float = 0.30
@export var lateral_relaxation_length: float = 0.30
@export var patch_relaxation_scale: float = 0.5
@export_range(0.0,1.0,0.01) var patch_force_correction_ratio: float = 0.20
@export_range(0.0,1.0,0.01) var aligning_moment_gain: float = 0.0
@export var max_aligning_moment: float = 900.0


func vertical_linear_stiffness() -> float:
	var pressure_ratio := inflation_pressure_pa / maxf(reference_pressure_pa,1.0)
	return radial_stiffness*clampf(1.0+radial_pressure_gain*(pressure_ratio-1.0),0.35,2.5)

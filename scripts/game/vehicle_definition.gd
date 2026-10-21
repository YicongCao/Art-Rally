class_name RallyVehicleDefinition
extends Resource

@export var vehicle_id: String = "A240"
@export var title: String = "A240 / 四驱宽体赛车"
@export var description: String = "牵引力充足 · 提前规划制动"
@export var drive_layout: String = "AWD"
var power_tier: int = 0
@export var physics_overrides: Dictionary = {}
@export var drivetrain_overrides: Dictionary = {}
@export var electric: bool = false
var resolved_physics: RallyVehicleConfig
var resolved_drivetrain: RallyDrivetrainConfig
var resolved_tire: RallyTireConfig
var garage_setup: Dictionary = {}
@export var power_ps: float = 288
@export var mass_kg: float = 1300
@export var wheelbase: float = 2.6
@export var track_width: float = 1.72
@export var body_size := Vector3(1.88,0.48,4.2)
@export var accent := Color("e8bf4d")
@export var paint := Color("245caa")
@export var number: int = 44
@export var revision: String = "fp3"
@export var appearance: RallyVehicleAppearance = preload("res://resources/visual/vehicle_appearance.tres")
@export var model_path: String = "res://assets/vehicles/A240.glb"
@export var cockpit_offset := Vector3(0,0.74,-0.80)
@export var hood_offset := Vector3(0,0.72,-1.40)


func short_title() -> String:
	return title.split(" · ")[0]


func physics_config() -> RallyVehicleConfig:
	if resolved_physics!=null: return resolved_physics.duplicate(true)
	var result := RallyVehicleConfig.new()
	result.body_mass = mass_kg
	result.wheelbase = wheelbase
	result.track_width = track_width
	result.body_size = body_size
	result.body_inertia = Vector3(650,1750,1850)*(mass_kg/1250.0)
	result.body_inertia.y *= pow(wheelbase/2.6,2)
	result.body_inertia.z *= pow(track_width/1.6,2)
	result.center_of_mass.z = -wheelbase*{"FWD":.10,"RWD":.02,"AWD":.06}[drive_layout]
	result.corner_brake_balance = false
	result.front_brake_bias = {"FWD":.62,"RWD":.59,"AWD":.61}[drive_layout]
	result.rear_anti_roll = {"FWD":5600.0,"RWD":4800.0,"AWD":5200.0}[drive_layout]
	result.contact_envelope = true
	for key: String in physics_overrides: result.set(key,physics_overrides[key])
	return result


func drivetrain_config() -> RallyDrivetrainConfig:
	if resolved_drivetrain!=null: return resolved_drivetrain.duplicate(true)
	var result := RallyDrivetrainConfig.new()
	result.drive_layout = drive_layout
	result.loose_surface_assist = true
	result.rated_power_ps = power_ps
	result.power_multiplier = RallyContentCatalog.POWER_MULTIPLIERS[power_tier]
	result.calibration_version = vehicle_id+"-"+revision
	for i: int in range(result.torque_values.size()): result.torque_values[i] *= power_ps/200.0
	for key: String in drivetrain_overrides: result.set(key,drivetrain_overrides[key])
	if not drivetrain_overrides.is_empty():
		result.rated_power_ps=power_ps
		for i: int in range(result.torque_values.size()): result.torque_values[i]*=RallyContentCatalog.POWER_MULTIPLIERS[power_tier]
	result.electric=electric
	return result


func tire_config() -> RallyTireConfig:
	return resolved_tire.duplicate(true) if resolved_tire!=null else preload("res://resources/vehicles/asphalt_tire.tres").duplicate(true)

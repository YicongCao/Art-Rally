class_name RallyVehicleDefinition
extends Resource

@export var vehicle_id: String = "A240"
@export var title: String = "A240 / 四驱宽体赛车"
@export var description: String = "牵引力充足 · 提前规划制动"
@export var drive_layout: String = "AWD"
var power_tier: int = 0
@export var power_ps: float = 240
@export var mass_kg: float = 1300
@export var wheelbase: float = 2.6
@export var track_width: float = 1.72
@export var body_size := Vector3(1.88,0.48,4.2)
@export var accent := Color("e8bf4d")
@export var paint := Color("245caa")
@export var number: int = 44
@export var revision: String = "fp2"
@export var model_path: String = "res://assets/vehicles/A240.glb"
@export var cockpit_offset := Vector3(0,0.74,-0.80)
@export var hood_offset := Vector3(0,0.72,-1.40)


func physics_config() -> RallyVehicleConfig:
	var result := RallyVehicleConfig.new()
	result.body_mass = mass_kg
	result.wheelbase = wheelbase
	result.track_width = track_width
	result.body_size = body_size
	result.body_inertia = Vector3(650,1750,1850)*(mass_kg/1250.0)
	result.body_inertia.y *= pow(wheelbase/2.6,2)
	result.body_inertia.z *= pow(track_width/1.6,2)
	result.corner_brake_balance = true
	result.front_brake_bias = {"FWD":.60,"RWD":.61,"AWD":.61}[drive_layout]
	result.rear_anti_roll = {"FWD":5600.0,"RWD":4800.0,"AWD":5200.0}[drive_layout]
	result.contact_envelope = true
	return result


func drivetrain_config() -> RallyDrivetrainConfig:
	var result := RallyDrivetrainConfig.new()
	result.drive_layout = drive_layout
	result.rated_power_ps = power_ps
	result.power_multiplier = RallyContentCatalog.POWER_MULTIPLIERS[power_tier]
	result.calibration_version = vehicle_id+"-"+revision
	for i: int in range(result.torque_values.size()): result.torque_values[i] *= power_ps/200.0
	return result

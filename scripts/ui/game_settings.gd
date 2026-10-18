class_name RallyGameSettings
extends RefCounted

const DEFAULTS := {"ghost":true,"engine_volume":0.85,"road_volume":0.8,"environment_volume":0.65,"interface_volume":0.85,"music_volume":0.45,"drive_layout":"AWD","reverse_assist":true,"volume":0.65,"lens_flare":true,"camera_motion":false,"low_detail":false,"automatic":true,"vibration":true,"keyboard_light":false,"steering_response":1.0,"return_rate":5.0,"throttle_rise":0.30,"brake_rise":0.12,"stick_deadzone":0.12,"brake_bias":0.62,"spring_scale":1.0,"tire_visual_gain":1.0}
const RANGES := {"engine_volume":Vector2(0,1),"road_volume":Vector2(0,1),"environment_volume":Vector2(0,1),"interface_volume":Vector2(0,1),"music_volume":Vector2(0,1),"volume":Vector2(0,1),"steering_response":Vector2(0.6,1.6),"return_rate":Vector2(2,8),"throttle_rise":Vector2(0.1,0.5),"brake_rise":Vector2(0.05,0.25),"stick_deadzone":Vector2(0.05,0.3),"brake_bias":Vector2(0.52,0.70),"spring_scale":Vector2(0.85,1.15),"tire_visual_gain":Vector2(0,2)}
var values: Dictionary = DEFAULTS.duplicate()
var path: String = "user://driving_settings.cfg"


func set_value(key: String,value: Variant) -> void:
	if not DEFAULTS.has(key): return
	if key=="drive_layout":
		values[key] = value if value is String and value in ["FWD","AWD","RWD"] else "AWD"
		return
	if RANGES.has(key):
		if (typeof(value)!=TYPE_FLOAT and typeof(value)!=TYPE_INT) or not is_finite(float(value)): value = DEFAULTS[key]
		values[key] = clampf(float(value),RANGES[key].x,RANGES[key].y)
	else:
		values[key] = value if typeof(value)==TYPE_BOOL else DEFAULTS[key]


func load_file() -> void:
	var file := ConfigFile.new()
	if file.load(path)!=OK: return
	for key: String in DEFAULTS: set_value(key,file.get_value("driving",key,DEFAULTS[key]))


func save_file() -> Error:
	var file := ConfigFile.new()
	for key: String in DEFAULTS: file.set_value("driving",key,values[key])
	return file.save(path)


func reset() -> void:
	values = DEFAULTS.duplicate()


func apply_input(controller: RallyInputController, light: bool) -> void:
	var profile := InputProfile.light_assist() if light else InputProfile.new()
	profile.steering_rate *= float(values.steering_response)
	profile.return_rate = values.return_rate
	profile.throttle_rise_seconds = float(values.throttle_rise)*(0.6 if light else 1.0)
	profile.brake_rise_seconds = values.brake_rise
	profile.stick_deadzone = values.stick_deadzone
	controller.filter.profile = profile

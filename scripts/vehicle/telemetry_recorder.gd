class_name VehicleTelemetryRecorder
extends RefCounted

const MAX_FRAMES := 120 * 120
const HEADER := "tick,speed_mps,px,py,pz,yaw_rad,roll_rad,pitch_rad,steer,throttle,brake,handbrake,gear,physics_usec,rpm,clutch"
var frames: Array[PackedFloat64Array] = []
var cursor: int = 0


func capture(vehicle: RallyVehicle) -> void:
	var row := PackedFloat64Array([
		vehicle.simulation_tick, vehicle.linear_velocity.length(), vehicle.position.x, vehicle.position.y, vehicle.position.z,
		vehicle.rotation.y, vehicle.rotation.z, vehicle.rotation.x, vehicle.command.steer, vehicle.command.throttle,
		vehicle.command.brake, vehicle.command.handbrake, vehicle.drivetrain.gear, vehicle.physics_usec,
		vehicle.drivetrain.rpm(), vehicle.drivetrain.clutch,
	])
	for wheel: RallyWheelState in vehicle.wheels:
		row.append_array(PackedFloat64Array([float(wheel.grounded), wheel.load, wheel.length, wheel.omega, wheel.slip, wheel.slip_angle, wheel.longitudinal_force, wheel.lateral_force]))
	if frames.size() < MAX_FRAMES:
		frames.append(row)
	else:
		frames[cursor] = row
	cursor = (cursor + 1) % MAX_FRAMES


func export_csv(vehicle: RallyVehicle) -> String:
	var directory := "user://telemetry"
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return ""
	var stem := directory + "/run_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_msec()]
	var file := FileAccess.open(stem + ".csv", FileAccess.WRITE)
	if file == null: return ""
	var header := HEADER
	for corner: String in ["fl", "fr", "rl", "rr"]:
		for field: String in ["contact", "load_n", "length_m", "omega_rads", "slip", "angle_rad", "fx_n", "fy_n"]:
			header += ",%s_%s" % [corner, field]
	file.store_line(header)
	var first := cursor if frames.size() == MAX_FRAMES else 0
	for i: int in range(frames.size()):
		var cells := PackedStringArray()
		for value: float in frames[(first + i) % frames.size()]: cells.append(str(value))
		file.store_csv_line(cells)
	file.close()
	var metadata := {"engine": Engine.get_version_info()["string"], "physics_hz": Engine.physics_ticks_per_second, "vehicle": _properties(vehicle.config), "tire": _properties(vehicle.tire), "drivetrain": _properties(vehicle.drivetrain.config), "frames": frames.size()}
	var info := FileAccess.open(stem + ".json", FileAccess.WRITE)
	if info != null: info.store_string(JSON.stringify(metadata, "\t"))
	return ProjectSettings.globalize_path(stem + ".csv")


func _properties(resource: Resource) -> Dictionary:
	var result := {}
	for property: Dictionary in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[property.name] = str(resource.get(property.name))
	return result

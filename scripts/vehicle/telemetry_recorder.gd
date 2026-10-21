class_name VehicleTelemetryRecorder
extends RefCounted

const MAX_FRAMES := 120 * 120
const HEADER := "tick,speed_mps,px,py,pz,yaw_rad,roll_rad,pitch_rad,steer,throttle,brake,handbrake,gear,physics_usec,rpm,clutch,shift_request,automatic,driver_source_id,auto_target_speed_mps,auto_lateral_m,auto_takeovers"
const AID_HEADER := "abs_enabled,abs_active,tc_mode,tc_active,tc_scale,esp_mode,esp_active,esp_scale,yaw_target_rads,beta_rad"
var frames: Array[PackedFloat64Array] = []
var cursor: int = 0


func capture(vehicle: RallyVehicle, driver: Dictionary = {}) -> void:
	var row := PackedFloat64Array([
		vehicle.simulation_tick, vehicle.linear_velocity.length(), vehicle.position.x, vehicle.position.y, vehicle.position.z,
		vehicle.rotation.y, vehicle.rotation.z, vehicle.rotation.x, vehicle.command.steer, vehicle.command.throttle,
		vehicle.command.brake, vehicle.command.handbrake, vehicle.drivetrain.gear, vehicle.physics_usec,
		vehicle.drivetrain.rpm(), vehicle.drivetrain.clutch,
		vehicle.last_shift_requested, float(vehicle.drivetrain.automatic),
		float(driver.get("source_id",RallyAutoDriver.Source.TEST_HARNESS)),
		float(driver.get("target_speed",0.0)),float(driver.get("lateral_error",0.0)),
		float(driver.get("takeovers",0)),
	])
	for wheel: RallyWheelState in vehicle.wheels:
		var patch := wheel.patch
		row.append_array(PackedFloat64Array([
			float(wheel.grounded),wheel.load,wheel.length,wheel.omega,wheel.slip,wheel.slip_angle,wheel.longitudinal_force,wheel.lateral_force,
			wheel.surface.surface_id,wheel.surface.water_depth,wheel.water_force.length(),
			wheel.radial_deflection,wheel.loaded_radius,wheel.effective_radius,
			patch.half_length*2.0,patch.half_width*2.0,patch.area,patch.samples.size(),patch.support_ratio,patch.wet_fraction,
			patch.pressure_center.x,patch.pressure_center.y,wheel.aligning_moment,wheel.slip_dissipation,wheel.radial_damping_power,wheel.diagnostic_flags,
		]))
	row.append_array(PackedFloat64Array([float(vehicle.aids.abs_enabled),float(vehicle.aids.abs_active),vehicle.drivetrain.tc_mode,float(vehicle.drivetrain.tc_active),vehicle.drivetrain.traction_scale,vehicle.aids.esp_mode,float(vehicle.aids.esp_active),vehicle.aids.engine_scale,vehicle.aids.yaw_target,vehicle.aids.beta]))
	for i: int in range(4): row.append_array(PackedFloat64Array([vehicle.aids.pressure[i],vehicle.aids.esp_brakes[i],vehicle.aids.requested_brakes[i],vehicle.aids.applied_brakes[i]]))
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
		for field: String in ["contact", "load_n", "length_m", "omega_rads", "slip", "angle_rad", "fx_n", "fy_n", "surface_id", "water_depth_m", "water_drag_n",
			"deflection_m","loaded_radius_m","effective_radius_m","patch_length_m","patch_width_m","patch_area_m2","sample_count","support_ratio","wet_fraction",
			"pressure_center_x_m","pressure_center_y_m","aligning_moment_nm","slip_dissipation_w","radial_damping_power_w","diagnostic_flags"]:
			header += ",%s_%s" % [corner, field]
	header+=","+AID_HEADER
	for corner: String in ["fl","fr","rl","rr"]:
		for field: String in ["abs_pressure","esp_brake_nm","requested_brake_nm","applied_brake_nm"]: header+=",%s_%s"%[corner,field]
	file.store_line(header)
	var first := cursor if frames.size() == MAX_FRAMES else 0
	for i: int in range(frames.size()):
		var cells := PackedStringArray()
		for value: float in frames[(first + i) % frames.size()]: cells.append(str(value))
		file.store_csv_line(cells)
	file.close()
	var metadata := {"engine": Engine.get_version_info()["string"], "physics_hz": Engine.physics_ticks_per_second, "vehicle": _properties(vehicle.config), "tire": _properties(vehicle.tire), "drivetrain": _properties(vehicle.drivetrain.config), "frames": frames.size()}
	metadata["driver_sources"] = RallyAutoDriver.SOURCE_NAMES
	metadata["aids_schema"] = "fp5-1"
	metadata["surfaces"] = []
	for profile: RallySurfaceProfile in RallySurfaceQuery.PROFILES: metadata.surfaces.append(_properties(profile))
	for profile: RallySurfaceProfile in [load("res://resources/surfaces/packed_dirt.tres"),load("res://resources/surfaces/wet_soil.tres")]: metadata.surfaces.append(_properties(profile))
	var info := FileAccess.open(stem + ".json", FileAccess.WRITE)
	if info == null: return ""
	info.store_string(JSON.stringify(metadata, "\t"))
	return ProjectSettings.globalize_path(stem + ".csv")


func _properties(resource: Resource) -> Dictionary:
	var result := {}
	for property: Dictionary in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[property.name] = str(resource.get(property.name))
	return result

class_name RallyDebugPanel
extends Control

const PAPER := Color("eee7d4")
const AMBER := Color("e8ac59")
const GREEN := Color("91d5b2")
const RED := Color("e56b4f")
const MUTED := Color("a6b5ab")
const GRID := Color("40564b")
const G_BALL_COLOR := RED
const SAMPLE_INTERVAL := 0.05
const MAX_SAMPLES := 120
const HISTORY_SECONDS := MAX_SAMPLES * SAMPLE_INTERVAL
const HISTORY_SPEED_MAX := 160.0
var car: RallyVehicle
var model: Dictionary = {}
var history: Array[Vector2] = []
var torque_history: Array[float] = []
var torque_max: float = 300
var title_font: Font = RallyFonts.bold()
var text_font: Font = RallyFonts.TEXT
var number_font: Font = RallyFonts.mono_bold()
var refresh_clock: float = 0
var sample_clock: float = 0
var previous_velocity := Vector3.ZERO
var velocity_valid: bool = false
var acceleration_g := Vector3.ZERO
var background := StyleBoxFlat.new()
var driver_state: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.bg_color = Color(0.035, 0.085, 0.07, 0.94)
	background.corner_radius_top_left = 5
	background.corner_radius_bottom_right = 5
	hide()


func bind_vehicle(vehicle: RallyVehicle) -> void:
	car = vehicle
	car.reset_completed.connect(clear_history)


func set_enabled(enabled: bool) -> void:
	if enabled == visible: return
	clear_history()
	visible = enabled
	if enabled and is_instance_valid(car):
		torque_max = 300
		for torque: float in car.drivetrain.config.torque_values:
			torque_max = maxf(torque_max, torque * 1.15)
		model = data_for(car, acceleration_g)
		model.merge(driver_state,true)
	queue_redraw()


func clear_history() -> void:
	history.clear()
	torque_history.clear()
	sample_clock = 0
	refresh_clock = 0
	velocity_valid = false
	acceleration_g = Vector3.ZERO


func set_driver_state(value: Dictionary) -> void:
	driver_state = value.duplicate()


func _physics_process(dt: float) -> void:
	if not visible or not is_instance_valid(car): return
	if get_tree().paused or car.reset_pending or car.freeze:
		velocity_valid = false
		return
	if velocity_valid:
		var measured := car.basis.inverse() * (car.linear_velocity - previous_velocity) / maxf(dt, 0.0001) / 9.81
		acceleration_g = acceleration_g.lerp(measured, 1 - exp(-12 * dt))
	previous_velocity = car.linear_velocity
	velocity_valid = true
	sample_clock += dt
	if sample_clock >= SAMPLE_INTERVAL:
		sample_clock -= SAMPLE_INTERVAL
		append_sample(Vector2(car.linear_velocity.length() * 3.6, car.drivetrain.rpm()), car.drivetrain.output_torque)


func append_sample(sample: Vector2, torque: float = 0) -> void:
	history.append(sample)
	torque_history.append(torque)
	if history.size() > MAX_SAMPLES:
		history.pop_front()
		torque_history.pop_front()


func _process(dt: float) -> void:
	if not visible or not is_instance_valid(car): return
	refresh_clock += dt
	if refresh_clock < SAMPLE_INTERVAL: return
	refresh_clock = 0
	model = data_for(car, acceleration_g)
	model.merge(driver_state,true)
	queue_redraw()


static func data_for(vehicle: RallyVehicle, g_force: Vector3 = Vector3.ZERO) -> Dictionary:
	var drive := vehicle.drivetrain
	var wheels: Array[Dictionary] = []
	var total_load := 0.0
	var front_load := 0.0
	var left_load := 0.0
	for i: int in range(vehicle.wheels.size()):
		var wheel := vehicle.wheels[i]
		var limit := RallyTireModel.capacity(wheel.load, vehicle.tire) * wheel.surface.grip(wheel.longitudinal_speed) if wheel.grounded else 0.0
		var force := Vector2(wheel.lateral_force, -wheel.longitudinal_force)
		wheels.append({
			"grounded": wheel.grounded, "load": wheel.load, "length_cm": wheel.length * 100,
			"travel": clampf((vehicle.config.suspension_rest - wheel.length) / maxf(vehicle.config.suspension_rest - vehicle.config.suspension_min, 0.0001), 0, 1),
			"slip": wheel.slip, "angle": rad_to_deg(wheel.slip_angle), "rpm": wheel.omega * 60 / TAU,
			"fx": wheel.longitudinal_force, "fy": wheel.lateral_force, "force": force / limit if limit > 0.01 else Vector2.ZERO,
			"usage": force.length() / limit if limit > 0.01 else 0.0, "limit": limit,
			"surface": RallySurfaceQuery.PROFILES[wheel.surface.surface_id].label, "water_mm": wheel.surface.water_depth * 1000,
			"water_drag": wheel.water_force.length(), "driven": drive.config.drive_layout == "AWD" or (i < 2 if drive.config.drive_layout == "FWD" else i >= 2),
			"deflection_mm":wheel.radial_deflection*1000.0,"loaded_radius_mm":wheel.loaded_radius*1000.0,"effective_radius_mm":wheel.effective_radius*1000.0,
			"patch_length_mm":wheel.patch.half_length*2000.0,"patch_width_mm":wheel.patch.half_width*2000.0,"patch_samples":wheel.patch.samples.size(),
			"support_ratio":wheel.patch.support_ratio,"wet_fraction":wheel.patch.wet_fraction,"pressure_center_mm":wheel.patch.pressure_center*1000.0,
			"aligning_moment":wheel.aligning_moment,"slip_power":wheel.slip_dissipation,"radial_power":wheel.radial_damping_power,
			"diagnostic_flags":wheel.diagnostic_flags,
		})
		total_load += wheel.load
		if i < 2: front_load += wheel.load
		if i % 2 == 0: left_load += wheel.load
	return {
		"wheels": wheels, "speed": vehicle.linear_velocity.length() * 3.6, "rpm": drive.rpm(),
		"redline": drive.config.redline_rpm, "power_ps": drive.config.rated_power_ps,
		"torque": drive.output_torque,
		"power_kw": drive.output_torque * drive.engine_omega / 1000,
		"clutch": drive.clutch, "clutch_torque": drive.clutch_torque, "shift_sync": drive.auto_shift_cut,
		"shifting": drive.shift_remaining > 0, "gas": vehicle.command.throttle, "effective_gas": drive.effective_throttle,
		"brake": vehicle.command.brake, "steer": vehicle.command.steer, "g": g_force,
		"gear": "R" if drive.gear < 0 else ("N" if drive.gear == 0 else str(drive.gear)),
		"layout": drive.config.drive_layout, "static_load": vehicle.mass * 9.81 / 4,
		"front_share": front_load / total_load if total_load > 1 else 0.0,
		"left_share": left_load / total_load if total_load > 1 else 0.0,
		"roll": rad_to_deg(vehicle.rotation.z), "pitch": rad_to_deg(vehicle.rotation.x),
		"yaw_rate": rad_to_deg(vehicle.angular_velocity.y), "tick": vehicle.simulation_tick,
		"physics_ms": vehicle.physics_usec / 1000.0,
	}


func _draw() -> void:
	if model.is_empty(): return
	var layout := RallyHUD.layout_for(size)
	draw_set_transform(layout.offset, 0, Vector2.ONE * float(layout.scale))
	panel(Rect2(24, 22, 1232, 74))
	text("ART / RALLY  ·  DEBUG", Vector2(40, 48), 21, PAPER, title_font)
	text("F9 显示/隐藏  ·  T 原始遥测  ·  F8 导出", Vector2(40, 76), 12, MUTED)
	var driver_label := str(model.get("label",""))
	text("%03d KM/H   G%s   %04d RPM   %s%s" % [model.speed, model.gear, model.rpm, model.layout, "   "+driver_label if not driver_label.is_empty() else ""], Vector2(430, 48), 20, PAPER, number_font)
	text("TICK %06d  /  %d Hz  /  %d FPS  /  PHYS %.2f ms" % [model.tick, Engine.physics_ticks_per_second, Engine.get_frames_per_second(), model.physics_ms], Vector2(430, 76), 12, MUTED, number_font)
	var status := "PAUSED" if get_tree().paused else ("SYNC DOWN" if model.shift_sync else ("SHIFTING" if model.shifting else "LIVE / 20 Hz"))
	text(status, Vector2(1090, 48), 14, AMBER if get_tree().paused or model.shift_sync else GREEN, title_font)
	if not driver_label.is_empty():
		text("TARGET %02d km/h  /  ERR %+.2f m" % [float(model.get("target_speed",0))*3.6,float(model.get("lateral_error",0))],Vector2(1025,76),11,AMBER,number_font)
	panel(Rect2(24, 131, 420, 50))
	text("WHEEL / CONTACT", Vector2(40, 153), 17, PAPER, title_font)
	text("Fz 载荷 / 行程 / 滑移 / 摩擦圆", Vector2(40, 174), 11, MUTED)
	for i: int in range(model.wheels.size()):
		_draw_wheel(i, Vector2(24 + i % 2 * 216, 192 + i / 2 * 256))
	_draw_engine()
	_draw_chassis()
	draw_rect(Rect2(455, 698, 801, 18), Color(0.035, 0.085, 0.07, 0.9))
	text("只读遥测 · 金色 = RPM · 绿色 = 净扭矩 Nm · 红点 = G 值 · 暂停冻结历史", Vector2(465, 711), 11, PAPER)


func _draw_wheel(index: int, at: Vector2) -> void:
	var wheel: Dictionary = model.wheels[index]
	panel(Rect2(at, Vector2(204, 244)))
	var contact_color := GREEN if wheel.grounded else RED
	draw_circle(at + Vector2(15, 21), 4, contact_color)
	text(["FL 左前", "FR 右前", "RL 左后", "RR 右后"][index], at + Vector2(27, 26), 16, PAPER)
	text("DRV" if wheel.driven else "FREE", at + Vector2(157, 25), 11, AMBER if wheel.driven else MUTED, number_font)
	text("%s / %s / %d mm" % ["接地" if wheel.grounded else "离地", wheel.surface, wheel.water_mm], at + Vector2(12, 47), 11, contact_color)
	text("Fz %4d N" % wheel.load, at + Vector2(12, 70), 13, PAPER, number_font)
	bar(Rect2(at + Vector2(12, 79), Vector2(180, 5)), wheel.load / maxf(model.static_load * 2, 1), contact_color)
	draw_line(at + Vector2(102, 77), at + Vector2(102, 86), MUTED, 1)
	text("SUS %4.1f cm / TIRE %4.1f mm" % [wheel.length_cm,wheel.deflection_mm], at + Vector2(12, 104), 10, PAPER, number_font)
	bar(Rect2(at + Vector2(12, 113), Vector2(180, 5)), wheel.travel, AMBER)
	text("PATCH %3d×%3d mm / %2d pts" % [wheel.patch_length_mm,wheel.patch_width_mm,wheel.patch_samples],at+Vector2(12,132),10,RED if wheel.diagnostic_flags!=0 else MUTED,number_font)
	text("SLIP %+.2f / %+.1f deg" % [wheel.slip, wheel.angle], at + Vector2(12, 151), 11, RED if absf(wheel.slip) > 0.35 else PAPER, number_font)
	text("Fx %+5d N" % wheel.fx, at + Vector2(12, 171), 11, PAPER, number_font)
	text("Fy %+5d N" % wheel.fy, at + Vector2(12, 191), 11, PAPER, number_font)
	var center := at + Vector2(159, 179)
	draw_arc(center, 25, 0, TAU, 40, GRID, 1, true)
	draw_line(center - Vector2(29, 0), center + Vector2(29, 0), GRID, 1, true)
	draw_line(center - Vector2(0, 29), center + Vector2(0, 29), GRID, 1, true)
	var force: Vector2 = Vector2(wheel.force).limit_length(1) * 25
	draw_line(center, center + force, contact_color, 2, true)
	draw_circle(center + force, 3, contact_color)
	text("GRIP %3d%% / %4d RPM" % [wheel.usage * 100, wheel.rpm], at + Vector2(12, 219), 11, PAPER, number_font)
	text("Mz %+4d / LOSS %4.1f kW / WET %2d%%" % [wheel.aligning_moment,wheel.slip_power/1000.0,wheel.wet_fraction*100],at+Vector2(12,237),9,MUTED,number_font)


func _draw_engine() -> void:
	panel(Rect2(840, 160, 416, 284))
	text("ENGINE / TORQUE HISTORY", Vector2(860, 186), 17, PAPER, title_font)
	text("%d PS" % model.power_ps, Vector2(1178, 186), 14, AMBER, number_font)
	var latest: float = torque_history[-1] if not torque_history.is_empty() else model.torque
	text("NET TORQUE %+6.1f Nm" % latest, Vector2(860, 212), 12, GREEN, number_font)
	var plot := Rect2(890, 238, 338, 134)
	text("Nm", Vector2(860, 230), 10, GREEN, number_font)
	for fraction: float in [0, 0.25, 0.5, 0.75, 1]:
		var y := plot.end.y - fraction * plot.size.y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID, 1, true)
		text("%4d" % lerpf(-100, torque_max, fraction), Vector2(849, y + 4), 10, GREEN, number_font)
	for age: float in [HISTORY_SECONDS, 4, 2, 0]:
		var x := plot.end.x - age / HISTORY_SECONDS * plot.size.x
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), GRID, 1, true)
		text("-%ds" % age if age > 0 else "NOW", Vector2(x - 12, 389), 10, MUTED, number_font)
	var points := torque_points(plot)
	if points.size() > 1: draw_polyline(points, GREEN, 2, true)
	if not points.is_empty(): draw_circle(points[-1], 3, GREEN)
	text("NET %+6.1f Nm / %+5.1f kW" % [model.torque, model.power_kw], Vector2(860, 410), 13, PAPER, number_font)
	text("CLUTCH %3d%% / %+4d Nm   GAS %.2f > %.2f" % [model.clutch * 100, model.clutch_torque, model.gas, model.effective_gas], Vector2(860, 432), 11, MUTED, number_font)


func history_x(index: int, count: int, plot: Rect2) -> float:
	return plot.end.x - (count - 1 - index) * SAMPLE_INTERVAL / HISTORY_SECONDS * plot.size.x


func torque_points(plot: Rect2) -> PackedVector2Array:
	var torques := PackedVector2Array()
	for i: int in range(torque_history.size()):
		var x := history_x(i, torque_history.size(), plot)
		torques.append(Vector2(x, plot.end.y - clampf((torque_history[i] + 100) / (torque_max + 100), 0, 1) * plot.size.y))
	return torques


func _draw_chassis() -> void:
	panel(Rect2(840, 460, 416, 236))
	text("CHASSIS / G-G & HISTORY", Vector2(860, 486), 17, PAPER, title_font)
	text("ROLL %+.1f° / PITCH %+.1f° / YAW %+.1f°/s" % [model.roll, model.pitch, model.yaw_rate], Vector2(860, 507), 11, MUTED, number_font)
	var center := Vector2(907, 569)
	draw_arc(center, 43, 0, TAU, 48, GRID, 1, true)
	draw_arc(center, 21.5, 0, TAU, 40, GRID, 1, true)
	draw_line(center - Vector2(43, 0), center + Vector2(43, 0), GRID, 1, true)
	draw_line(center - Vector2(0, 43), center + Vector2(0, 43), GRID, 1, true)
	var acceleration: Vector3 = model.g
	draw_circle(center + Vector2(acceleration.x, acceleration.z).limit_length(2) * 21.5, 4, G_BALL_COLOR)
	text("2g", Vector2(923, 619), 10, MUTED, number_font)
	text("LAT  %+.2fg" % acceleration.x, Vector2(860, 628), 11, PAPER, number_font)
	text("LONG %+.2fg" % -acceleration.z, Vector2(860, 643), 11, PAPER, number_font)
	text("6s  RPM / SPEED", Vector2(995, 535), 11, MUTED, number_font)
	var plot := Rect2(995, 547, 239, 65)
	for fraction: float in [0, 0.5, 1]:
		var y := plot.end.y - fraction * plot.size.y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID, 1, true)
	if history.size() > 1:
		var speeds := PackedVector2Array()
		var rpms := PackedVector2Array()
		for i: int in range(history.size()):
			var x := history_x(i, history.size(), plot)
			speeds.append(Vector2(x, plot.end.y - clampf(history[i].x / HISTORY_SPEED_MAX, 0, 1) * plot.size.y))
			rpms.append(Vector2(x, plot.end.y - clampf(history[i].y / model.redline, 0, 1) * plot.size.y))
		draw_polyline(speeds, GREEN, 1.5, true)
		draw_polyline(rpms, AMBER, 1.5, true)
	text("0–%d RPM" % model.redline, Vector2(995, 628), 10, AMBER, number_font)
	text("0–160 km/h", Vector2(1130, 628), 10, GREEN, number_font)
	text("LOAD FRONT %d%% / LEFT %d%%" % [model.front_share * 100, model.left_share * 100], Vector2(995, 643), 10, MUTED, number_font)
	for i: int in range(3):
		var x := 860.0 + i * 130
		var value: float = [model.steer, model.gas, model.brake][i]
		text(["STEER", "GAS", "BRAKE"][i] + " %+.2f" % value, Vector2(x, 667), 10, PAPER, number_font)
		var track := Rect2(x, 677, 112, 5)
		if i == 0:
			draw_rect(track, GRID)
			draw_rect(Rect2(x + 56 + minf(value, 0) * 56, 677, absf(value) * 56, 5), AMBER)
		else: bar(track, value, GREEN if i == 1 else RED)


func panel(rect: Rect2) -> void:
	draw_style_box(background, rect)
	draw_line(rect.position + Vector2(12, 0), Vector2(rect.end.x - 12, rect.position.y), AMBER, 1, true)


func bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_rect(rect, GRID)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0, 1), rect.size.y)), color)


func text(value: String, at: Vector2, font_size: int, color: Color = PAPER, font: Font = null) -> void:
	draw_string(text_font if font == null else font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

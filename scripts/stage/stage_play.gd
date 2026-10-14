extends "res://scripts/dev/driving_lab.gd"

const NOTE_TEXT := {
	"LEFT_MEDIUM": "左弯 3", "RIGHT_MEDIUM": "右弯 3",
	"LEFT_TIGHT": "左急弯 / 减速", "RIGHT_TIGHT": "右急弯 / 减速",
	"MUD_NARROW": "泥地 · 路面收窄", "WATER": "前方积水 · 减速直行",
	"ASPHALT": "进入柏油", "GRAVEL": "进入砂石", "CREST_JUMP": "坡顶跳跃 · 保持直线",
	"FINISH": "终点 · 通过后减速",
}

var generator: RallyStageGenerator
var session := RallyStageSession.new()
var stage_hud: Label
var checkpoint_visual: MeshInstance3D
var respawn_wait: bool = false


func _ready() -> void:
	generator = $Stage
	session.setup(generator.route)
	super._ready()
	vehicle.config.contact_envelope = true
	telemetry_visible = false
	controls.restart_requested.connect(_restart)
	controls.mode_requested.connect(_toggle_mode)
	vehicle.reset_completed.connect(func(): respawn_wait = false)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(785, 22)
	panel.custom_minimum_size = Vector2(460, 180)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.10, 0.08, 0.93)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	stage_hud = Label.new()
	stage_hud.add_theme_font_size_override("font_size", 22)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC"])
	stage_hud.add_theme_font_override("font", font)
	panel.add_child(stage_hud)
	notice.text = "W/S 油门/制动 · A/D 转向 · 空格 手刹\nR 恢复 (+5s) · F5/手柄 Back 重跑 · F4 练习/计时\nF7 测试场 · F3 接触模式 · T 遥测 · Esc 暂停"
	notice.add_theme_font_override("font", font)
	checkpoint_visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(6.6, 0.025, 0.18)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e9bf64")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	checkpoint_visual.mesh = mesh
	add_child(checkpoint_visual)


func _spawn_pose() -> Transform3D:
	return generator.route.pose_at(8)


func _driver_command(speed: float, dt: float) -> DriverCommand:
	if not session.accepts_input() or respawn_wait:
		var held := DriverCommand.new()
		held.brake = 1
		return held
	return controls.sample(speed, dt)


func _physics_process(dt: float) -> void:
	if get_tree().paused: return
	recorder.capture(vehicle)
	if respawn_wait: return
	session.step(vehicle.position, vehicle.linear_velocity.length(), dt)
	if vehicle.position.y < generator.route.position_at(session.progress).y - 12 or float(session.projection.get("distance", 0)) > 35:
		_reset()


func _process(dt: float) -> void:
	super._process(dt)
	if stage_hud == null: return
	var state := "练习" if session.practice else "计时"
	if session.phase == RallyStageSession.Phase.COUNTDOWN: state = "准备发车 %d" % ceili(session.countdown)
	elif session.phase == RallyStageSession.Phase.ARMED: state = "出发！穿过起点开始计时"
	elif session.phase == RallyStageSession.Phase.FINISHED: state = "完赛！F5 重跑"
	if get_tree().paused: state = "已暂停 · Enter / Start 继续"
	stage_hud.text = "夕照松岭 / SUNSET RIDGE\n%s\n时间 %s  罚时 +%.0fs\n进度 %d / %d m   检查点 %d/%d\n" % [state, _format_time(session.total_time()), session.penalty, session.progress, generator.route.length - 30, session.next_gate, session.gates.size()]
	if session.note_remaining > 0:
		stage_hud.text += "%s · %d m" % [NOTE_TEXT.get(session.current_note, session.current_note), maxf(0, session.note_s - session.progress)]
	elif session.phase == RallyStageSession.Phase.RUNNING:
		stage_hud.text += "下一检查点 %d m" % maxf(0, session.gates[session.next_gate] - session.progress)
	if session.phase == RallyStageSession.Phase.RUNNING and float(session.projection.get("s", 0)) > session.gates[session.next_gate] + 10:
		stage_hud.text += "\n漏过检查点 · R 恢复后重过"
	elif vehicle.linear_velocity.dot(generator.route.tangent_at(session.progress)) < -2:
		stage_hud.text += "\n当前逆行 · 请掉头"
	checkpoint_visual.visible = session.next_gate < session.gates.size()
	if checkpoint_visual.visible:
		checkpoint_visual.transform = generator.route.pose_at(session.gates[session.next_gate], 0.025)
	readout.text = "ART RALLY / SUNSET RIDGE\n%03d km/h    GEAR %s    %s" % [vehicle.linear_velocity.length() * 3.6, _gear_name(), RallySurfaceQuery.PROFILES[vehicle.wheels[0].surface.surface_id].label]


func _format_time(seconds: float) -> String:
	return "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60)]


func _reset() -> void:
	if respawn_wait or session.phase == RallyStageSession.Phase.FINISHED: return
	controls.clear()
	respawn_wait = true
	vehicle.request_reset(session.recover())
	camera_snap = true


func _restart() -> void:
	get_tree().paused = false
	controls.resume()
	respawn_wait = true
	vehicle.request_reset(session.restart())
	recorder = VehicleTelemetryRecorder.new()
	camera_snap = true


func _toggle_mode() -> void:
	session.practice = not session.practice
	_restart()

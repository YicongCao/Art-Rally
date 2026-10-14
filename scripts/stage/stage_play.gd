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
var game_hud: RallyHUD
var game_hud_clock: float = 0
var checkpoint_visual: MeshInstance3D
var respawn_wait: bool = false
var result_safety_reset: bool = false
var presentation := RallyStagePresentation.new()


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
	layer.layer = 5
	add_child(layer)
	game_hud = RallyHUD.new()
	layer.add_child(game_hud)
	game_hud.set_route(generator.route)
	readout.get_parent().get_parent().visible = false
	checkpoint_visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(6.6, 0.025, 0.18)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e9bf64")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	checkpoint_visual.mesh = mesh
	add_child(checkpoint_visual)
	presentation.build(self)


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
	if session.phase == RallyStageSession.Phase.FINISHED:
		if vehicle.position.y < generator.route.position_at(generator.route.length).y - 12 and not result_safety_reset:
			result_safety_reset = true
			vehicle.request_reset(generator.route.pose_at(session.gates[-1] + 8))
		return
	if vehicle.position.y < generator.route.position_at(session.progress).y - 12 or float(session.projection.get("distance", 0)) > 35:
		_reset()
	elif presentation.scenery.spectator_intrusion(vehicle.position):
		_reset()


func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(game_hud): return
	readout.get_parent().get_parent().visible = telemetry_visible
	game_hud.visible = not telemetry_visible
	checkpoint_visual.visible = telemetry_visible and session.next_gate < session.gates.size()
	if checkpoint_visual.visible:
		checkpoint_visual.transform = generator.route.pose_at(session.gates[session.next_gate],0.025)
	game_hud_clock += dt
	if game_hud_clock >= 0.05:
		game_hud_clock = 0
		game_hud.refresh(RallyHUD.data_for(vehicle,session,get_tree().paused))
	presentation.update(dt)


func _exit_tree() -> void:
	presentation.dispose()


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
	result_safety_reset = false
	recorder = VehicleTelemetryRecorder.new()
	camera_snap = true


func _toggle_mode() -> void:
	session.practice = not session.practice
	_restart()

extends "res://scripts/stage/stage_play.gd"

signal completed(result: Dictionary)
signal return_requested
signal tutorial_finished
var challenge: RallyChallengeDefinition
var profile: RallyProfileStore
var trajectory := RallyGhostRecording.new()
var ghost := RallyGhostPlayer.new()
var free_practice: bool = false
var tutorial: bool = false
var tutorial_step: int = 0
var tutorial_label: Label
var previous_note: int = 0
var previous_phase_audio: int = -1
var audio_director: RallyAudioDirector


func start() -> void:
	vehicle_definition = challenge.vehicle
	for key: String in profile.data.settings: preferences.set_value(key,profile.data.settings[key])
	initialize_gameplay()
	var plate := RallyPlateText.display(profile.data.get("plate",""))
	RallyVehiclePlate.attach(presentation.car_style.body,challenge.vehicle,plate)
	session.practice = free_practice or tutorial
	_apply_preferences()
	controls.allow_mechanical_shortcuts = session.practice
	controls.bindings = profile.data.bindings.duplicate()
	# Official challenges retain fixed mechanical setup. Developer tools remain in the lab.
	for key: String in ["brake_bias","spring_scale"]:
		pause_menu.widgets[key].editable = session.practice
	pause_menu.actions.add_back("返回赛道选择",func(): return_requested.emit(),true)
	pause_menu.message.text = "练习不计入奖牌与个人纪录" if session.practice else "正式挑战 · 机械调校固定 · 自动驾驶跑段不计成绩"
	_build_spatial_ambience()
	add_child(ghost)
	ghost.build(challenge.vehicle,profile.load_ghost(challenge))
	var bucket := profile.result_for(challenge.key())
	result_summary = {"human_best":bucket.get("best",{})}
	if not profile.message.is_empty():
		recovery_notice = profile.message
		recovery_notice_time = 8
	if tutorial:
		var layer := CanvasLayer.new()
		layer.layer = 18
		add_child(layer)
		var panel := PanelContainer.new()
		panel.position = Vector2(32,140)
		layer.add_child(panel)
		var list := VBoxContainer.new()
		panel.add_child(list)
		tutorial_label = Label.new()
		tutorial_label.add_theme_font_override("font",RallyFonts.TEXT)
		tutorial_label.add_theme_font_size_override("font_size",20)
		list.add_child(tutorial_label)
		pause_menu.button(list,"跳过教学",_complete_tutorial)
		_update_tutorial()


func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	if not is_instance_valid(vehicle) or get_tree().paused or respawn_wait: return
	if session.phase==RallyStageSession.Phase.RUNNING: trajectory.capture(session.total_time(),vehicle)
	if tutorial:
		if tutorial_step==0 and vehicle.linear_velocity.length()>5: tutorial_step = 1
		elif tutorial_step==1 and vehicle.command.brake>0.3 and vehicle.linear_velocity.length()<4: tutorial_step = 2
		elif tutorial_step==2 and absf(vehicle.command.steer)>0.3: tutorial_step = 3
		elif tutorial_step==3 and session.next_note>0: tutorial_step = 4
		elif tutorial_step==4 and session.reset_count>0: tutorial_step = 5
		_update_tutorial()


func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(vehicle): return
	ghost.update(session.total_time(),vehicle.position,preferences.values.ghost and session.phase==RallyStageSession.Phase.RUNNING)
	if audio_director!=null:
		if session.next_note!=previous_note:
			audio_director.cue("warning" if session.current_note in ["WATER","CREST_JUMP","MUD_NARROW"] else "note")
			previous_note = session.next_note
		if int(session.phase)!=previous_phase_audio:
			if session.phase==RallyStageSession.Phase.ARMED: audio_director.cue("start")
			previous_phase_audio = session.phase


func _record_finish() -> void:
	if finish_recorded: return
	finish_recorded = true
	trajectory.capture(session.total_time(),vehicle,true)
	var result := {"elapsed":session.elapsed,"penalty":session.penalty,"total_time":session.total_time(),"splits":Array(session.split_times),"source":auto_driver.source_name(controls.active_device),"reset_count":session.reset_count,"practice":session.practice,"recorded_at":Time.get_unix_time_from_system()}
	var outcome := profile.record(challenge,result,trajectory.payload(challenge.key(),session.total_time()))
	result["outcome"] = outcome
	completed.emit.call_deferred(result)


func _recover(seconds: float,reason: String) -> void:
	var before := session.total_time()
	super._recover(seconds,reason)
	if session.total_time()>before: trajectory.recovery(before,session.total_time())


func _restart() -> void:
	trajectory.reset()
	super._restart()
	ghost.recording = profile.load_ghost(challenge)


func _apply_preferences() -> void:
	super._apply_preferences()
	if not session.practice and vehicle_definition!=null:
		var baseline := vehicle_definition.physics_config()
		vehicle.config.front_brake_bias = baseline.front_brake_bias
		vehicle.config.static_compression = baseline.static_compression
	if audio_director!=null: audio_director.apply_settings(preferences)


func _save_preferences() -> void:
	profile.data.settings = preferences.values.duplicate()
	if profile.save_file()!=OK and is_instance_valid(pause_menu): pause_menu.message.text = profile.message


func _open_vehicle_selection(_can_cancel: bool = false) -> void:
	return_requested.emit()


func _toggle_mode() -> void:
	# Mode is chosen before loading; a timed run cannot be made eligible by toggling practice.
	recovery_notice = "请返回赛道选择切换挑战与练习模式"
	recovery_notice_time = 3


func _toggle_debug() -> void:
	if session.practice: super._toggle_debug()


func _switch_scene(_path: String) -> void:
	return_requested.emit()


func _update_tutorial() -> void:
	if not is_instance_valid(tutorial_label): return
	tutorial_label.text = ["01 / 使用 W 或右扳机加速","02 / 使用 S 或左扳机制动至低速","03 / 使用 A、D 或左摇杆转向","04 / 继续前进，留意前方路书和提示音","05 / 按 R 或手柄 Y 恢复车辆（正式挑战会罚时）","06 / 正式挑战：通过全部检查点，争取更快成绩\n教学已完成，可返回选关开始挑战"][tutorial_step]
	if tutorial_step==5: _complete_tutorial()


func _complete_tutorial() -> void:
	profile.data.tutorial_complete = true
	profile.save_file()
	tutorial_finished.emit.call_deferred()


func _build_spatial_ambience() -> void:
	var biome: String = challenge.stage.environment_id
	var stations: Array[float] = [350.0,1150.0,2100.0]
	if biome=="highland": stations.assign(challenge.stage.culverts)
	for station: float in stations:
		var player := AudioStreamPlayer3D.new()
		player.stream = RallyAudioDirector.asset({"autumn":"forest","coast":"coast","highland":"highland"}[biome],true)
		player.bus = "Environment"
		player.volume_db = -16
		player.unit_size = 18
		player.max_distance = 100
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		player.position = generator.route.position_at(station)+generator.route.rights[generator.route.index_at(station)]*(-28 if biome=="coast" else 16)
		if DisplayServer.get_name()!="headless": player.play()


func _refresh_result_summary() -> void:
	if profile!=null and challenge!=null: result_summary = {"human_best":profile.result_for(challenge.key()).get("best",{})}

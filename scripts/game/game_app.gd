class_name RallyGameApp
extends Node

const STAGE_SCENE := preload("res://scenes/game/challenge.tscn")
const PLAY_SCRIPT := preload("res://scripts/game/challenge_play.gd")
const MEDALS := ["尚未获得","铜牌","银牌","金牌"]
var profile := RallyProfileStore.new()
var prefs := RallyGameSettings.new()
var audio := RallyAudioDirector.new()
var layer := CanvasLayer.new()
var ui: Control
var column: VBoxContainer
var backdrop: RallyMenuBackdrop
var race: Node3D
var chosen_stage: String = "sunset_ridge"
var chosen_vehicle: String = "F160"
var practice: bool = false
var tutorial: bool = false
var screen: String = ""
var loading: bool = false
var status_label: Label
var progress_bar: ProgressBar
var binding_wait: String = ""
var binding_button: Button
var test_mode: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	test_mode = "--test-defaults" in OS.get_cmdline_user_args()
	if test_mode: profile.path = "user://test-session/profile.json"
	profile.load_file()
	for key: String in profile.data.settings: prefs.set_value(key,profile.data.settings[key])
	chosen_stage = profile.data.last_stage
	chosen_vehicle = profile.data.last_vehicle
	audio.settings = prefs
	var output := str(profile.data.get("output_device","Default"))
	if output in AudioServer.get_output_device_list(): AudioServer.output_device = output
	add_child(audio)
	audio.apply_settings(prefs)
	layer.layer = 40
	add_child(layer)
	show_home()
	if "--package-smoke" in OS.get_cmdline_user_args(): _package_check.call_deferred()


func _package_check() -> void:
	await RallyPackageSmoke.run_app(self)


func _theme() -> Theme:
	var result := Theme.new()
	result.default_font = RallyFonts.regular()
	result.default_font_size = 18
	result.set_color("font_color","Label",Color("f3ead2"))
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("24413d") if state=="normal" else Color("416256")
		style.border_color = Color("efbd69")
		style.border_width_bottom = 2 if state in ["focus","hover"] else 0
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		result.set_stylebox(state,"Button",style)
		result.set_color("font_color","Button",Color("f8efd8"))
	return result


func _page(title: String, subtitle: String, name_id: String) -> void:
	screen = name_id
	if is_instance_valid(ui):
		layer.remove_child(ui)
		ui.queue_free()
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = _theme()
	layer.add_child(ui)
	backdrop = RallyMenuBackdrop.new()
	backdrop.biome = RallyContentCatalog.stage(chosen_stage).environment_id
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(backdrop)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right"]: margins.add_theme_constant_override("margin_"+side,48)
	for side: String in ["top","bottom"]: margins.add_theme_constant_override("margin_"+side,28)
	ui.add_child(margins)
	var scroll := ScrollContainer.new()
	margins.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",14)
	scroll.add_child(column)
	_label(column,"ART / RALLY     —     FIRST PLAYABLE",15,Color("edbc75"))
	_label(column,title,42)
	_label(column,subtitle,17,Color("c8d5c7"))
	if not profile.message.is_empty(): _label(column,profile.message,16,Color("ffd38b"))


func _label(parent: Node,text: String,font_size: int = 18,color: Color = Color("f3ead2")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	if font_size>=24: label.add_theme_font_override("font",RallyFonts.bold())
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _button(parent: Node,text: String,action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220,48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func(): audio.cue("ui"); action.call())
	parent.add_child(button)
	return button


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	parent.add_child(row)
	return row


func _card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.055,.12,.12,.90)
	for side: String in ["left","right","top","bottom"]: style.set_content_margin(SIDE_LEFT if side=="left" else (SIDE_RIGHT if side=="right" else (SIDE_TOP if side=="top" else SIDE_BOTTOM)),18)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	return box


func show_home() -> void:
	audio.set_scene()
	_page("穿过山野，追逐下一秒。","三条风景赛段 · 三种驾驶性格 · 你的最佳轨迹", "home")
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 340
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(left)
	_button(left,"开始计时挑战  →",func(): practice=false; tutorial=false; show_stages()).grab_focus()
	_button(left,"自由练习",func(): practice=true; tutorial=false; show_stages())
	_button(left,"驾驶教学 · 约 2 分钟",show_tutorial)
	_button(left,"成绩册",show_records)
	_button(left,"设置与声音试听",show_settings)
	_button(left,"制作名单",show_credits)
	_button(left,"退出游戏",func(): get_tree().quit())
	_label(column,"W / S 加速制动    A / D 转向    空格 手刹    R 恢复    C 镜头    Esc 暂停\n手柄：左右扳机加速 / 制动，左摇杆转向，A 手刹，Y 恢复，X 镜头",15,Color("b4c6b8"))


func show_stages() -> void:
	_page("选择一段旅途", "自由练习 · 不记录奖牌和个人最佳" if practice else "计时挑战 · 全部赛道和车辆已开放", "stages")
	var row := _row(column)
	for id: String in RallyContentCatalog.STAGES:
		var definition := RallyContentCatalog.stage(id)
		var card := _card(row)
		var preview := RallyMenuBackdrop.new()
		preview.biome = definition.environment_id
		preview.custom_minimum_size = Vector2(260,155)
		card.add_child(preview)
		_label(card,definition.title,26)
		_label(card,definition.subtitle,16)
		_label(card,"%.2f km · %s"%[definition.target_length/1000.0,{"autumn":"砂石 / 泥地 / 柏油","coast":"沿海柏油","highland":"砂石 / 泥地 / 浅水"}[definition.environment_id]],16)
		var medals := ""
		for vehicle_id: String in RallyContentCatalog.VEHICLES:
			var challenge := RallyContentCatalog.challenge(id,vehicle_id)
			medals += vehicle_id+" "+MEDALS[int(profile.result_for(challenge.key()).get("medal",0))]+"\n"
		_label(card,medals.strip_edges(),16,Color("e9bd78"))
		_button(card,"选择赛段 →",func(): chosen_stage=id; show_vehicles())
	_button(column,"← 主菜单",show_home)


func show_vehicles() -> void:
	_page("选择你的搭档",RallyContentCatalog.stage(chosen_stage).title+" · 三种驱动，三种节奏", "vehicles")
	var row := _row(column)
	for id: String in RallyContentCatalog.VEHICLES:
		var vehicle := RallyContentCatalog.vehicle(id)
		var card := _card(row)
		_vehicle_preview(card,vehicle)
		_label(card,vehicle.title,24,vehicle.accent.lightened(.3))
		_label(card,"%s · %d PS · %d kg"%[vehicle.drive_layout,vehicle.power_ps,vehicle.mass_kg],17)
		_label(card,vehicle.description,16)
		_button(card,"驾驶 "+id,func(): chosen_vehicle=id; show_briefing())
	_button(column,"← 选择赛道",show_stages)


func _vehicle_preview(parent: Node,definition: RallyVehicleDefinition) -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(270,180)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,200)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	var body := Node3D.new()
	viewport.add_child(body)
	if ResourceLoader.exists(definition.model_path): body.add_child(load(definition.model_path).instantiate())
	for side: float in [-1,1]:
		for axle: float in [-1,1]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = .33
			mesh.bottom_radius = .33
			mesh.height = .23
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("273532")
			mesh.material = material
			wheel.mesh = mesh
			wheel.rotation.z = PI/2
			wheel.position = Vector3(side*definition.track_width/2,-.32,axle*definition.wheelbase/2)
			body.add_child(wheel)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-25,0)
	light.light_energy = 1.8
	viewport.add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c4d5dc")
	world.environment.ambient_light_energy = .7
	viewport.add_child(world)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(4,2.1,-5)
	camera.look_at(Vector3(0,.3,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2


func show_briefing() -> void:
	var challenge := RallyContentCatalog.challenge(chosen_stage,chosen_vehicle)
	_page(challenge.stage.title,challenge.vehicle.title+" · "+("练习" if practice else "计时挑战"),"briefing")
	_label(column,"完整通过检查点，三个分段合成一次旅程。\n手动恢复 +5 秒，越界恢复 +10 秒；成绩包含罚时。\n自动驾驶或中途接管的跑段不会获得奖牌，也不会覆盖你的最佳轨迹。",22)
	var targets := challenge.thresholds()
	_label(column,"金牌 %s    银牌 %s    铜牌 %s"%[_time(targets[2]),_time(targets[1]),_time(targets[0])],27,Color("edbc75"))
	_label(column,"奖牌目标已按真人无恢复基准冻结。" if challenge.human_calibrated else "当前奖牌目标为试玩暂定值，真人标定后将更新挑战版本。",15)
	_label(column,"首次驾驶建议使用自动换挡。提前减速、平稳转向，出弯后逐渐加大油门。",19)
	_button(column,"驶向起点 →",start_race).grab_focus()
	_button(column,"← 更换车辆",show_vehicles)


func start_race() -> void:
	if loading: return
	loading = true
	_page("准备出发",RallyContentCatalog.stage(chosen_stage).title,"loading")
	status_label = _label(column,"读取赛段配置",22)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 24
	column.add_child(progress_bar)
	await get_tree().process_frame
	profile.data.last_stage = chosen_stage
	profile.data.last_vehicle = chosen_vehicle
	_save()
	race = STAGE_SCENE.instantiate()
	race.managed_flow = true
	race.challenge = RallyContentCatalog.challenge(chosen_stage,chosen_vehicle)
	race.profile = profile
	race.free_practice = practice
	race.tutorial = tutorial
	race.audio_director = audio
	var generator: RallyStageGenerator = race.get_node("Stage")
	generator.auto_build = false
	generator.definition = race.challenge.stage
	add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	await generator.build_incremental(_loading_progress)
	_loading_progress(.70,"布置地貌、植被与车辆")
	await get_tree().process_frame
	race.start()
	_loading_progress(.94,"检查起点、声音与个人幽灵")
	race.completed.connect(show_results)
	race.return_requested.connect(leave_race)
	race.tutorial_finished.connect(leave_race)
	audio.set_scene(generator.definition.environment_id)
	await get_tree().physics_frame
	_loading_progress(1,"准备就绪")
	await get_tree().process_frame
	ui.visible = false
	race.set_process(true)
	race.set_physics_process(true)
	race.controls.resume()
	loading = false
	screen = "race"


func _loading_progress(value: float,description: String) -> void:
	progress_bar.value = value*100
	status_label.text = description


func leave_race() -> void:
	if is_instance_valid(race):
		race.controls.suspend()
		for key: String in profile.data.settings: prefs.set_value(key,profile.data.settings[key])
		remove_child(race)
		race.queue_free()
		race = null
	get_tree().paused = false
	tutorial = false
	audio.set_scene()
	show_stages()


func retry() -> void:
	if is_instance_valid(race):
		race._restart()
		ui.visible = false
		audio.set_scene(race.challenge.stage.environment_id)
		screen = "race"


func show_results(result: Dictionary) -> void:
	race.controls.suspend()
	get_tree().paused = true
	race.pause_menu.visible = false
	ui.visible = true
	audio.set_scene()
	var outcome: Dictionary = result.outcome
	_page("新的个人纪录！" if outcome.get("new_best",false) else "抵达终点",race.challenge.stage.title+" / "+chosen_vehicle,"results")
	audio.cue("record" if outcome.get("new_best",false) else ("medal" if outcome.get("medal",0)>0 else "finish"))
	_label(column,_time(result.total_time),64,Color("efbf6e"))
	_label(column,"行驶 %s   +   罚时 %.0f 秒"%[_time(result.elapsed),result.penalty],21)
	var cumulative := 0.0
	var split_text := ""
	for i: int in range(result.splits.size()):
		split_text += "第 %d 段  %s     "%[i+1,_time(result.splits[i]-cumulative)]
		cumulative = result.splits[i]
	_label(column,split_text,21)
	if outcome.get("eligible",false):
		_label(column,MEDALS[int(outcome.get("medal",0))],28)
		var previous := float(outcome.get("previous_best",-1))
		if previous>0: _label(column,"对比上次最佳：%+.2f 秒"%(result.total_time-previous),20)
		var target: float = race.challenge.next_target(result.total_time)
		_label(column,"已达到金牌目标" if target<0 else "距离下一级奖牌还需快 %.2f 秒"%maxf(0,result.total_time-target),20)
		if not outcome.get("saved",false): _label(column,"成绩尚未保存："+str(outcome.get("reason","")),20,Color("ffba80"))
	else: _label(column,"练习 / 自动驾驶 / 混合接管成绩 · 不计奖牌与个人纪录",20)
	if not str(outcome.get("reason","")).is_empty(): _label(column,outcome.reason,17)
	var row := _row(column)
	_button(row,"再跑一次",retry).grab_focus()
	_button(row,"更换车辆",func(): leave_race(); show_vehicles())
	_button(row,"返回赛道选择",leave_race)


func show_records() -> void:
	_page("你的山野足迹","每个赛道与车型组合分别保存最佳成绩与一条个人幽灵。","records")
	var bronze := 0
	var gold := 0
	for id: String in RallyContentCatalog.STAGES:
		_label(column,RallyContentCatalog.stage(id).title,25)
		var row := _row(column)
		for car: String in RallyContentCatalog.VEHICLES:
			var challenge := RallyContentCatalog.challenge(id,car)
			var result := profile.result_for(challenge.key())
			var medal := int(result.get("medal",0))
			if medal>0: bronze+=1
			if medal==3: gold+=1
			var card := _card(row)
			_label(card,car+" · "+MEDALS[medal],20)
			_label(card,_time(result.best.total_time) if result.has("best") else "等待你的第一条轨迹",18)
	_label(column,"全金达成 · 每一段旅途都留下了金色轨迹！" if gold==9 else ("基础挑战完成 · 九枚奖牌，九段旅途。" if bronze==9 else "基础挑战 %d / 9    金牌 %d / 9"%[bronze,gold]),21,Color("efbf6e"))
	_button(column,"← 主菜单",show_home)


func show_tutorial() -> void:
	practice = true
	tutorial = true
	chosen_stage = "sunset_ridge"
	chosen_vehicle = "F160"
	_page("先熟悉你的车","一段可随时跳过的小练习，使用夕照松岭的起点。","tutorial")
	_label(column,"加速与制动 → 转向 → 路书 → 恢复车辆\n\nW / S，A / D，R；或手柄扳机、左摇杆、Y。\n正式比赛需要完整通过检查点；恢复会增加罚时。",24)
	_button(column,"开始教学",start_race).grab_focus()
	_button(column,"跳过，直接开始挑战",func(): tutorial=false; practice=false; show_stages())


func show_settings() -> void:
	_page("让驾驶适合你","设置保存在本机；比赛中也可按 Esc 调整操作与画面。","settings")
	var row := _row(column)
	var left := _card(row)
	var right := _card(row)
	for entry: Array in [["volume","主音量"],["engine_volume","发动机"],["road_volume","轮胎与路面"],["environment_volume","环境"],["interface_volume","界面与路书"],["music_volume","菜单音乐"]]:
		var line := _row(left)
		var label := _label(line,entry[1],17)
		label.custom_minimum_size.x = 140
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .01
		slider.value = prefs.values[entry[0]]
		slider.custom_minimum_size.x = 200
		line.add_child(slider)
		slider.value_changed.connect(func(value: float): prefs.set_value(entry[0],value); audio.apply_settings(prefs); _save())
	_button(left,"试听提示音",func(): audio.cue("start"))
	_label(left,audio.diagnostic(),14)
	var outputs := OptionButton.new()
	for device: String in AudioServer.get_output_device_list():
		outputs.add_item(device)
		if device==AudioServer.output_device: outputs.select(outputs.item_count-1)
	outputs.item_selected.connect(func(index: int): AudioServer.output_device=outputs.get_item_text(index); profile.data["output_device"]=AudioServer.output_device; _save())
	left.add_child(outputs)
	for entry: Array in [["ghost","显示个人幽灵"],["automatic","自动换挡"],["keyboard_light","键盘轻辅助"],["low_detail","降低草簇与散石密度"],["camera_motion","驾驶舱震动"],["lens_flare","镜头光斑"],["vibration","手柄震动"]]:
		var check := CheckButton.new()
		check.text = entry[1]
		check.button_pressed = prefs.values[entry[0]]
		check.toggled.connect(func(value: bool): prefs.set_value(entry[0],value); _save())
		right.add_child(check)
	_button(column,"键盘按键映射",show_bindings)
	_button(column,"恢复默认设置",func(): prefs.reset(); profile.data.bindings={}; audio.apply_settings(prefs); _save(); show_settings())
	_button(column,"← 主菜单",show_home)


func show_bindings() -> void:
	_page("键盘按键映射","点击操作后按新按键；Esc 取消。方向键始终可用。","bindings")
	var grid := GridContainer.new()
	grid.columns = 3
	column.add_child(grid)
	for entry: Array in [[KEY_W,"加速"],[KEY_S,"制动"],[KEY_A,"左转"],[KEY_D,"右转"],[KEY_SPACE,"手刹"],[KEY_R,"恢复"],[KEY_C,"镜头"],[KEY_Q,"降挡"],[KEY_E,"升挡"]]:
		var key := str(entry[0])
		var button := _button(grid,entry[1]+"  "+OS.get_keycode_string(int(profile.data.bindings.get(key,entry[0]))),func(): pass)
		button.pressed.connect(func(): binding_wait=key; binding_button=button; button.text="请按新按键…")
	_button(column,"← 设置",show_settings)


func _input(event: InputEvent) -> void:
	if binding_wait.is_empty() or event is not InputEventKey or not event.pressed: return
	if event.physical_keycode!=KEY_ESCAPE:
		var reserved := [KEY_ENTER,KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_M,KEY_T,KEY_L,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]
		if event.physical_keycode in reserved:
			binding_button.text = "此键保留，请换一个按键"
			get_viewport().set_input_as_handled()
			return
		# Swap mappings so every action remains reachable.
		var previous: int = profile.data.bindings.get(binding_wait,int(binding_wait))
		for key: int in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_SPACE,KEY_R,KEY_C,KEY_Q,KEY_E]:
			if key!=int(binding_wait) and int(profile.data.bindings.get(str(key),key))==event.physical_keycode: profile.data.bindings[str(key)] = previous
		profile.data.bindings[binding_wait] = event.physical_keycode
		_save()
	binding_wait = ""
	get_viewport().set_input_as_handled()
	show_bindings()


func show_credits() -> void:
	_page("沿途的创作者","Art Rally / 原创复古计时拉力","credits")
	_label(column,"引擎：Godot Engine / Jolt Physics\n车辆、风景、涂装：Art Rally 原创低多边形设计\n音效与音乐：项目内原创程序合成，全部离线打包\n字体与依赖许可：见随包 ASSET_CREDITS.md\n\n感谢每一位试驾并留下反馈的玩家。",24)
	_label(column,"试玩版 · 奖牌阈值待真人标定。Windows 与实体手柄需在对应设备完成验收。",16)
	_button(column,"← 主菜单",show_home)


func _save() -> void:
	profile.data.settings = prefs.values.duplicate()
	if profile.save_file()!=OK and is_instance_valid(column): _label(column,profile.message,16,Color("ffd38b"))


static func _time(seconds: float) -> String:
	return "%02d:%05.2f"%[int(seconds)/60,fmod(seconds,60)]

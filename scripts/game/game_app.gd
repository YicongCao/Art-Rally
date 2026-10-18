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
var chosen_power_tier: int = 0
var vehicle_power_choices: Dictionary = {}
var practice: bool = false
var tutorial: bool = false
var screen: String = ""
var loading: bool = false
var status_label: Label
var progress_bar: ProgressBar
var binding_wait: String = ""
var binding_button: Button
var test_mode: bool = false
var plate_input: LineEdit
var plate_preview: RallyPlatePreview
var plate_error: Label
var album := RallyPhotoAlbum.new()
var gallery_photos: Array = []
var immersive_ui: Control
var replay_sliders: Array[HSlider] = []
var replay_clocks: Array[Label] = []
var replay_buttons: Array[Button] = []
var replay_cameras: Array[OptionButton] = []
var immersive_idle: float = 0
var transitions := RallyPageTransition.new()
var focus_memory: Dictionary = {}
var page_back: Callable


func _ready() -> void:
	RallyMenuInput.install()
	process_mode = Node.PROCESS_MODE_ALWAYS
	test_mode = "--test-defaults" in OS.get_cmdline_user_args()
	if test_mode and profile.path=="user://player/profile.json": profile.path = "user://test-session/profile.json"
	profile.load_file()
	for key: String in profile.data.settings: prefs.set_value(key,profile.data.settings[key])
	chosen_stage = profile.data.last_stage
	chosen_vehicle = profile.data.last_vehicle
	chosen_power_tier = mini(int(profile.data.get("last_power_tier",0)),profile.unlocked_power_tier())
	audio.settings = prefs
	var output := str(profile.data.get("output_device","Default"))
	if output in AudioServer.get_output_device_list(): AudioServer.output_device = output
	add_child(audio)
	audio.apply_settings(prefs)
	add_child(transitions)
	layer.layer = 40
	add_child(layer)
	if not test_mode and str(profile.data.get("plate","")).is_empty(): show_plate_setup(true)
	else: show_home()
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
	var previous_screen := screen
	var previous_ui := ui
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(previous_ui) and focus!=null and previous_ui.is_ancestor_of(focus):
		focus_memory[previous_screen] = RallyMenuInput.token(focus)
	page_back = Callable()
	_restore_page_focus.call_deferred(name_id)
	transitions.finish_slide()
	screen = name_id
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = _theme()
	var paper := name_id in ["loading","plate"]
	ui.set_meta("paper",paper)
	layer.add_child(ui)
	backdrop = RallyMenuBackdrop.new()
	backdrop.biome = RallyContentCatalog.stage(chosen_stage).environment_id
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(backdrop)
	if paper:
		backdrop.visible = false
		var ground := ColorRect.new()
		ground.color = Color("f1f0e9")
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.add_child(ground)
	if name_id=="loading":
		var patina := RallyRacingPatina.new()
		patina.page_corner=true
		patina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.add_child(patina)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right"]: margins.add_theme_constant_override("margin_"+side,48)
	for side: String in ["top","bottom"]: margins.add_theme_constant_override("margin_"+side,28)
	ui.add_child(margins)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	margins.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10 if name_id in ["stages","vehicles","loading"] else 14)
	scroll.add_child(column)
	if name_id!="home":
		_label(column,title,42)
		if not subtitle.is_empty(): _label(column,subtitle,17,Color("64716b") if paper else Color("c8d5c7"))
	if not profile.message.is_empty(): _label(column,profile.message,16,Color("ffd38b"))
	if is_instance_valid(previous_ui):
		if previous_screen!=name_id and previous_screen not in ["race","results",""] and name_id!="results" and not transitions.busy:
			var levels := {"home":0,"stages":1,"vehicles":2,"loading":3,"photo":2,"bindings":2,"plate":2}
			var direction := -1.0 if int(levels.get(name_id,1))<int(levels.get(previous_screen,1)) else 1.0
			transitions.slide(previous_ui,ui,direction)
		else: previous_ui.queue_free()


func _label(parent: Node,text: String,font_size: int = 18,color: Color = Color("f3ead2")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	if font_size>=24: label.add_theme_font_override("font",RallyFonts.bold())
	label.add_theme_color_override("font_color",Color("1c302b") if ui.get_meta("paper",false) and color == Color("f3ead2") else color)
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


func _actions(back_title: String,back: Callable,confirm_title: String = "",confirm: Callable = Callable()) -> RallyActionBar:
	page_back = back if not back_title.is_empty() else Callable()
	return RallyActionBar.create(column,back_title,func(): audio.cue("ui"); back.call(),confirm_title,func(): audio.cue("ui"); confirm.call())


func _selected_card(card: VBoxContainer,selected: bool) -> void:
	if not selected: return
	var panel := card.get_parent() as PanelContainer
	RallyRacingPatina.select_mark(panel,true)
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = Color("e6b66d")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel",style)


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
	_page("","", "home")
	column.add_theme_constant_override("separation",0)
	var logo := RallyTitleLogo.new()
	logo.custom_minimum_size = Vector2(0,210)
	column.add_child(logo)
	var main := _row(column)
	main.add_theme_constant_override("separation",12)
	var challenge := _menu_tile(main,"开始计时挑战","","challenge",Color("dfb372"),func(): practice=false; tutorial=false; show_stages(),true)
	challenge.size_flags_stretch_ratio = 1.4
	challenge.grab_focus()
	_menu_tile(main,"自由练习","","practice",Color("315b51"),func(): practice=true; tutorial=false; show_stages(),true)
	_menu_tile(main,"设置","","settings",Color("2b464d"),show_settings,true)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	column.add_child(gap)
	var secondary := _row(column)
	secondary.add_theme_constant_override("separation",10)
	_menu_tile(secondary,"相册","","gallery",Color("203b37"),show_gallery,false)
	_menu_tile(secondary,"操作指南","","guide",Color("203b37"),show_guide,false)
	_menu_tile(secondary,"成绩册","","records",Color("203b37"),show_records,false)
	_menu_tile(secondary,"制作名单","","credits",Color("203b37"),show_credits,false)
	_menu_tile(secondary,"退出","","exit",Color("203b37"),_quit_game,false)


func show_guide() -> void:
	_page("操作指南","", "guide")
	var row := _row(column)
	for entry: Array in [["键盘","W / ↑　加速
S / ↓　制动，停稳按住 0.6 秒倒车
A D / ← →　转向
空格　手刹　　R　恢复
C　镜头　　Q E　换挡
T　遥测与调试
Esc　暂停"],["手柄","十字键 / 左摇杆　菜单导航
A / ×　确认　　B / ○　返回
右 / 左扳机　加速 / 制动
左摇杆　转向
右摇杆　环视　　R3　回正
A　手刹　　Y　恢复
X　镜头　　肩键　换挡
Start　暂停"],["回放","空格　播放 / 暂停
C　切换镜头
← →　前后 5 秒
Esc　退出沉浸模式"]]:
		var card := _card(row)
		_label(card,entry[0],26)
		_label(card,entry[1],19)
		if entry[0]=="回放":
			var legend := VBoxContainer.new()
			legend.add_theme_constant_override("separation",6)
			card.add_child(legend)
			for item: Array in [["handbrake","手刹"],["shift","换挡"]]:
				var pair := _row(legend)
				pair.add_theme_constant_override("separation",4)
				var icon := TextureRect.new()
				icon.texture = load("res://assets/ui/icons/"+item[0]+".svg")
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(20,20)
				pair.add_child(icon)
				var label := _label(pair,item[1],16)
				label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_actions("← 主菜单",show_home)


func _menu_tile(parent: Node,title: String,caption: String,icon: String,color: Color,action: Callable,large: bool) -> Button:
	var tile := _button(parent,title,action)
	tile.custom_minimum_size = Vector2(210,190) if large else Vector2(160,82)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL if large else Control.SIZE_SHRINK_BEGIN
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.tooltip_text = title.replace("  →", "") + (" · " + caption if not caption.is_empty() else "")
	var ink := Color("183b34") if icon == "challenge" else Color("f4ead6")
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color(ink,0.94)
		style.set_border_width_all(3 if state == "focus" else 0)
		if state == "hover":
			style.border_color = Color(ink,0.48)
			style.set_border_width_all(1)
		elif state == "pressed":
			style.border_color = Color("efbd69",0.9)
			style.border_width_bottom = 3
		tile.add_theme_stylebox_override(state,style)
		# Keep Button.text for accessibility and navigation; the child labels provide tile layout.
		tile.add_theme_color_override("font_" + state + "_color" if state != "normal" else "font_color",Color.TRANSPARENT)
	# Blur the live landscape behind the buttons while keeping icons and labels crisp.
	# The strong dark tint gives the title tiles less transparency than the driving HUD.
	var acrylic := ColorRect.new()
	acrylic.name = "AcrylicSurface"
	acrylic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	acrylic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	acrylic.color = Color(color,0.94)
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://assets/shaders/hud_acrylic.gdshader")
	glass.set_shader_parameter("frost",0.58)
	acrylic.material = glass
	tile.add_child(acrylic)
	var margins := MarginContainer.new()
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margins.add_theme_constant_override("margin_" + side,24 if large else 14)
	tile.add_child(margins)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",5)
	margins.add_child(content)
	var glyph := TextureRect.new()
	glyph.texture = load("res://assets/ui/icons/" + icon + ".svg")
	glyph.custom_minimum_size = Vector2(54,54) if large else Vector2(26,26)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	glyph.self_modulate = ink
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(glyph)
	if large:
		var space := Control.new()
		space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(space)
	_label(content,title.replace("  →", ""),29 if large else 18,ink)
	if large and not caption.is_empty(): _label(content,caption,15,ink.lightened(.06) if icon == "challenge" else Color("cad9d2"))
	return tile


func show_stages() -> void:
	_page("选择一段旅途", "自由练习 · 不记录奖牌和个人最佳" if practice else "计时挑战", "stages")
	var row := _row(column)
	for id: String in RallyContentCatalog.STAGES:
		var definition := RallyContentCatalog.stage(id)
		var card := _card(row)
		card.add_theme_constant_override("separation",10)
		_selected_card(card,id == chosen_stage)
		var preview := RallyMenuBackdrop.new()
		preview.biome = definition.environment_id
		preview.ink_wash = false
		preview.custom_minimum_size = Vector2(260,145)
		card.add_child(preview)
		_label(card,definition.title,26)
		_label(card,definition.subtitle,16)
		_label(card,"%.2f km · %s"%[definition.target_length/1000.0,definition.surface_summary()],16)
		var medals := ""
		for vehicle_id: String in RallyContentCatalog.VEHICLES:
			var challenge := RallyContentCatalog.challenge(id,vehicle_id,chosen_power_tier)
			medals += vehicle_id+" "+MEDALS[int(profile.result_for(challenge.key()).get("medal",0))]+"\n"
		_label(card,medals.strip_edges(),16,Color("e9bd78"))
		var select := _button(card,"选择赛段",func(): chosen_stage=id; show_stages())
		select.set_meta("focus_key","stage:"+id)
		RallySelectionStyle.apply(select,id==chosen_stage)
	_actions("← 主菜单",show_home,"确认赛道 →",show_vehicles).primary_button.grab_focus()


func show_vehicles() -> void:
	_page("选择你的搭档",RallyContentCatalog.stage(chosen_stage).title+" · 为每台车选择动力版本", "vehicles")
	chosen_power_tier = mini(chosen_power_tier,profile.unlocked_power_tier())
	vehicle_power_choices[chosen_vehicle] = chosen_power_tier
	var row := _row(column)
	for id: String in RallyContentCatalog.VEHICLES:
		var selected_tier := mini(int(vehicle_power_choices.get(id,0)),profile.unlocked_power_tier())
		var vehicle := RallyContentCatalog.vehicle(id,selected_tier)
		var card := _card(row)
		card.set_meta("vehicle_id",id)
		card.add_theme_constant_override("separation",8)
		_selected_card(card,id == chosen_vehicle)
		_vehicle_preview(card,vehicle)
		_label(card,vehicle.title,24,vehicle.accent.lightened(.3))
		_label(card,"%s · %d PS · %d kg"%[vehicle.drive_layout,vehicle.power_ps,vehicle.mass_kg],17)
		_label(card,vehicle.description,16)
		var tiers := _row(card)
		tiers.add_theme_constant_override("separation",6)
		for tier: int in range(3):
			var available := tier<=profile.unlocked_power_tier()
			var caption := RallyContentCatalog.power_label(id,tier)
			var option := _button(tiers,caption,_select_vehicle_variant.bind(id,tier))
			option.custom_minimum_size = Vector2(0,42)
			option.add_theme_font_size_override("font_size",15)
			RallySelectionStyle.apply(option,tier==selected_tier)
			if not available: option.icon = load("res://assets/ui/icons/lock.svg")
			option.disabled = not available
			option.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
			option.set_meta("focus_key","power:%s:%d"%[id,tier])
			option.set_meta("power_tier",tier)
			option.set_meta("vehicle_id",id)
			option.tooltip_text = "原厂组金牌解锁" if tier==1 else ("进阶组金牌解锁" if tier==2 else "原厂动力")
		var select := _button(card,"选择 "+id,_select_vehicle_variant.bind(id,selected_tier))
		select.set_meta("focus_key","vehicle:"+id)
		RallySelectionStyle.apply(select,id==chosen_vehicle)
	_actions("← 选择赛道",show_stages,"驾驶 %s · %s →"%[chosen_vehicle,RallyContentCatalog.power_label(chosen_vehicle,chosen_power_tier)],start_race).primary_button.grab_focus()


func _select_vehicle_variant(id: String,tier: int) -> void:
	if tier>profile.unlocked_power_tier(): return
	chosen_vehicle = id
	chosen_power_tier = tier
	vehicle_power_choices[id] = tier
	show_vehicles()


func _vehicle_preview(parent: Node,definition: RallyVehicleDefinition) -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(270,120)
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
	if ResourceLoader.exists(definition.model_path):
		body.add_child(load(definition.model_path).instantiate())
		RallyVehiclePlate.attach(body,definition,str(profile.data.get("plate","")))
	for side: float in [-1,1]:
		for axle: float in [-1,1]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = RallyWheelMeshes.tire(.34)
			wheel.rotation.z = PI/2
			wheel.position = Vector3(side*definition.track_width/2,-.32,axle*definition.wheelbase/2)
			body.add_child(wheel)
			for face: float in [-1,1]:
				var hub := MeshInstance3D.new()
				hub.mesh=RallyWheelMeshes.five_spoke()
				hub.position.y=face*.125
				wheel.add_child(hub)
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


func _loading_page() -> void:
	var challenge := RallyContentCatalog.challenge(chosen_stage,chosen_vehicle,chosen_power_tier)
	_page(challenge.stage.title,("自由练习" if practice else "计时挑战")+" / "+RallyContentCatalog.power_label(chosen_vehicle,chosen_power_tier),"loading")
	status_label = _label(column,"正在加载",18)
	progress_bar = RallyLoadingProgress.new()
	progress_bar.custom_minimum_size.y = 26
	column.add_child(progress_bar)
	var layout := _row(column)
	layout.add_theme_constant_override("separation",32)
	var preview := RallyMenuBackdrop.new()
	preview.biome = challenge.stage.environment_id
	preview.ink_wash = false
	preview.breakout = true
	var frame := Control.new()
	frame.custom_minimum_size=Vector2(350,250)
	frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	layout.add_child(frame)
	frame.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left=18
	preview.offset_top=14
	preview.offset_right=-24
	preview.offset_bottom=-30
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 1.4
	details.add_theme_constant_override("separation",10)
	layout.add_child(details)
	_label(details,challenge.vehicle.title+" · %d PS"%challenge.vehicle.power_ps,25)
	var facts := _row(details)
	for entry: Array in [["赛段长度","%.2f km" % (challenge.stage.target_length/1000.0)],["驱动形式",challenge.vehicle.drive_layout]]:
		var fact := VBoxContainer.new()
		fact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		facts.add_child(fact)
		_label(fact,entry[0],13,Color("65746c"))
		_label(fact,entry[1],25)
	_label(column,"奖牌目标",13,Color("65746c"))
	var targets := challenge.thresholds()
	var medals := _row(column)
	for i: int in range(3):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e7e9e1")
		style.content_margin_left = 18
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel",style)
		medals.add_child(panel)
		var medal := _row(panel)
		var glyph := TextureRect.new()
		glyph.texture = load("res://assets/ui/icons/medal_" + ["gold","silver","bronze"][i] + ".svg")
		glyph.self_modulate = [Color("a77828"),Color("657c89"),Color("a16140")][i]
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.custom_minimum_size = Vector2(56,70)
		medal.add_child(glyph)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		medal.add_child(text)
		_label(text,["金牌","银牌","铜牌"][i],15,Color("65746c"))
		_label(text,_time(targets[2-i]),31)



func start_race() -> void:
	if loading: return
	loading = true
	chosen_power_tier = mini(chosen_power_tier,profile.unlocked_power_tier())
	_loading_page()
	if transitions.sliding and transitions.sliding.is_running(): await transitions.sliding.finished
	await get_tree().process_frame
	profile.data.last_stage = chosen_stage
	profile.data.last_vehicle = chosen_vehicle
	profile.data["last_power_tier"] = chosen_power_tier
	_save()
	race = STAGE_SCENE.instantiate()
	race.managed_flow = true
	race.challenge = RallyContentCatalog.challenge(chosen_stage,chosen_vehicle,chosen_power_tier)
	race.profile = profile
	race.free_practice = practice
	race.tutorial = tutorial
	race.audio_director = audio
	album.directory = profile.path.get_base_dir()+"/gallery"
	race.photo_album = album
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
	race.controls.suspend()
	_loading_progress(.94,"检查起点、声音与个人幽灵")
	race.completed.connect(show_results)
	race.return_requested.connect(leave_race)
	race.tutorial_finished.connect(leave_race)
	audio.set_scene(generator.definition.environment_id)
	await get_tree().physics_frame
	_loading_progress(1,"准备就绪")
	await get_tree().process_frame
	await transitions.cover(true)
	audio.cue("flag_sweep")
	ui.visible = false
	screen = "race"
	await transitions.reveal(true)
	race.set_process(true)
	race.set_physics_process(true)
	race.controls.resume()
	loading = false
	screen = "race"


func _loading_progress(value: float,_description: String) -> void:
	progress_bar.value = value*100
	status_label.text = "正在加载" if value<.94 else "即将发车"


func leave_race(destination: String = "stages") -> void:
	if transitions.busy: return
	if DisplayServer.get_name()!="headless": await transitions.cover(false)
	_clear_race(destination)
	if transitions.busy: await transitions.reveal(false)


func _clear_race(destination: String) -> void:
	_close_immersive()
	audio.playback = false
	if is_instance_valid(race):
		race.controls.suspend()
		for key: String in profile.data.settings: prefs.set_value(key,profile.data.settings[key])
		race.feedback.dispose()
		remove_child(race)
		race.queue_free()
		race = null
	get_tree().paused = false
	tutorial = false
	audio.set_scene()
	if destination=="vehicles": show_vehicles()
	else: show_stages()


func retry() -> void:
	_close_immersive()
	audio.playback = false
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
	if race.replay!=null:
		race.replay.stop()
		race.replay.queue_free()
	race.replay = RallyReplayController.new()
	race.add_child(race.replay)
	var replaying: bool = race.replay.begin(race,race.trajectory.payload(race.challenge.key(),result.total_time),RallyPlateText.display(profile.data.get("plate","")))
	audio.playback = replaying
	audio.set_scene(race.challenge.stage.environment_id if replaying else "")
	var outcome: Dictionary = result.outcome
	_page("新的个人纪录" if outcome.get("new_best",false) else "抵达终点",race.challenge.stage.title+" / "+chosen_vehicle+" / "+RallyContentCatalog.power_label(chosen_vehicle,chosen_power_tier),"results")
	if replaying:
		backdrop.visible = false
		var wash := TextureRect.new()
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var texture := GradientTexture2D.new()
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(.02,.06,.055,.82),Color(.02,.06,.055,.18)])
		texture.gradient = gradient
		texture.fill_to = Vector2(1,0)
		wash.texture = texture
		ui.add_child(wash)
		ui.move_child(wash,1)
	audio.cue("record" if outcome.get("new_best",false) else ("medal" if outcome.get("medal",0)>0 else "finish"))
	var body := _row(column)
	var info := _card(body)
	info.get_parent().custom_minimum_size.x = 430
	info.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_label(info,_time(result.total_time),52,Color("efbf6e"))
	_label(info,"行驶 %s   /   +%.0f s"%[_time(result.elapsed),result.penalty],17)
	var cumulative := 0.0
	var splits := _row(info)
	for i: int in range(result.splits.size()):
		var split := VBoxContainer.new()
		split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		splits.add_child(split)
		_label(split,"%02d"%[i+1],13,Color("b8c7b8"))
		_label(split,_time(result.splits[i]-cumulative),22)
		cumulative = result.splits[i]
	if outcome.get("eligible",false):
		var badge := _row(info)
		var earned := int(outcome.get("medal",0))
		if earned>0:
			var icon := TextureRect.new()
			icon.texture = load("res://assets/ui/icons/medal_"+["bronze","silver","gold"][earned-1]+".svg")
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(30,38)
			badge.add_child(icon)
		_label(badge,MEDALS[earned],23)
		var previous := float(outcome.get("previous_best",-1))
		if previous>0: _label(info,"PB  %+.2f s"%(result.total_time-previous),20)
		var target: float = race.challenge.next_target(result.total_time)
		if target>0: _label(info,"下枚奖牌  −%.2f s"%maxf(0,result.total_time-target),17)
		if int(outcome.get("unlocked_tier",-1))>0: _label(info,"更高马力已解锁",20,Color("efbf6e"))
		if not outcome.get("saved",false): _label(info,"保存失败 · "+str(outcome.get("reason","")),16,Color("ffba80"))
	else: _label(info,"练习 / 自动驾驶",17)
	var view := Control.new()
	view.custom_minimum_size = Vector2(420,260)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(view)
	if replaying: _replay_controls(column)
	var actions := _actions("返回赛道选择",leave_race,"再跑一次",retry)
	var change := _button(actions,"更换车辆",leave_race.bind("vehicles"))
	change.custom_minimum_size = Vector2(180,40)
	change.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.move_child(change,1)
	actions.primary_button.icon = load("res://assets/ui/icons/replay.svg")
	actions.primary_button.grab_focus()
	if outcome.get("new_best",false):
		var confetti := RallyRecordConfetti.new()
		confetti.position = Vector2(48,16)
		confetti.size = Vector2(600,220)
		ui.add_child(confetti)


func _replay_controls(parent: Node,immersive: bool = false) -> void:
	var controls := _row(parent)
	controls.add_theme_constant_override("separation",10)
	if immersive:
		var back := _button(controls,"← 成绩",func(): _set_immersive(false))
		back.custom_minimum_size = Vector2(96,40)
	var play := _button(controls,"",func(): race.replay.playing = not race.replay.playing)
	play.custom_minimum_size = Vector2(48,44)
	for state: String in ["normal","hover","pressed","focus"]:
		var style := play.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_left = 8
		style.content_margin_right = 8
		play.add_theme_stylebox_override(state,style)
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play.tooltip_text = "播放 / 暂停 · 空格"
	play.icon = load("res://assets/ui/icons/pause.svg")
	play.expand_icon = true
	play.add_theme_constant_override("icon_max_width",22)
	replay_buttons.append(play)
	var camera := OptionButton.new()
	for title: String in RallyReplayController.CAMERA_NAMES: camera.add_icon_item(load("res://assets/ui/icons/camera.svg"),title)
	camera.expand_icon = true
	camera.add_theme_constant_override("icon_max_width",20)
	camera.select(race.replay.mode)
	camera.custom_minimum_size = Vector2(152,44)
	camera.item_selected.connect(func(index: int): race.replay.set_camera(index))
	controls.add_child(camera)
	replay_cameras.append(camera)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = race.replay.duration
	slider.step = .01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 180
	slider.value_changed.connect(func(value: float): race.replay.seek(value))
	controls.add_child(slider)
	replay_sliders.append(slider)
	var clock := _label(controls,"00:00 / 00:00",15)
	clock.custom_minimum_size.x = 160
	clock.size_flags_horizontal = Control.SIZE_SHRINK_END
	replay_clocks.append(clock)
	if not immersive:
		var full := _button(controls,"沉浸回放",func(): _set_immersive(true))
		full.icon = load("res://assets/ui/icons/expand.svg")
		full.expand_icon = true
		full.add_theme_constant_override("icon_max_width",20)
		full.custom_minimum_size = Vector2(170,44)
		full.size_flags_horizontal = Control.SIZE_SHRINK_END


func _set_immersive(enabled: bool) -> void:
	if not is_instance_valid(race) or race.replay==null or not race.replay.active: return
	ui.visible = not enabled
	immersive_idle = 0
	race.replay.framing_offset = 0 if enabled else 4.2
	race.replay.snap = true
	if enabled and not is_instance_valid(immersive_ui):
		immersive_ui = Control.new()
		immersive_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		immersive_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		immersive_ui.theme = _theme()
		layer.add_child(immersive_ui)
		var panel := PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		panel.offset_top = -68
		panel.offset_left = 24
		panel.offset_right = -24
		panel.offset_bottom = -16
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.035,.08,.075,.72)
		style.content_margin_left = 12
		style.content_margin_right = 12
		panel.add_theme_stylebox_override("panel",style)
		immersive_ui.add_child(panel)
		_replay_controls(panel,true)
	if is_instance_valid(immersive_ui): immersive_ui.visible = enabled
	screen = "replay" if enabled else "results"
	if enabled:
		immersive_ui.get_child(0).show()
		replay_buttons[-1].grab_focus()
	else: _restore_page_focus.call_deferred("results")


func _close_immersive() -> void:
	if is_instance_valid(immersive_ui): immersive_ui.queue_free()
	immersive_ui = null
	replay_sliders.clear()
	replay_clocks.clear()
	replay_buttons.clear()
	replay_cameras.clear()


func _process(dt: float) -> void:
	if screen=="replay" and is_instance_valid(immersive_ui):
		immersive_idle+=dt
		var near_bar := get_viewport().get_mouse_position().y>get_viewport().get_visible_rect().size.y-110
		immersive_ui.get_child(0).visible = immersive_idle<3 or near_bar
	if not is_instance_valid(race) or race.replay==null or not race.replay.active: return
	for selector: OptionButton in replay_cameras:
		if is_instance_valid(selector) and selector.selected!=race.replay.mode: selector.select(race.replay.mode)
	for slider: HSlider in replay_sliders:
		if is_instance_valid(slider): slider.set_value_no_signal(race.replay.clock)
	for label: Label in replay_clocks:
		if is_instance_valid(label): label.text = _time(race.replay.clock)+" / "+_time(race.replay.duration)
	for button: Button in replay_buttons:
		if is_instance_valid(button): button.icon = load("res://assets/ui/icons/pause.svg" if race.replay.playing else "res://assets/ui/icons/play.svg")


func show_gallery() -> void:
	_page("沿途影像","自动保留最近 64 张航拍", "gallery")
	album.directory = profile.path.get_base_dir()+"/gallery"
	gallery_photos = album.entries()
	if gallery_photos.is_empty(): _label(column,"比赛途中，直播直升机会为你留下航拍照片。",22)
	var gallery_scroll := ScrollContainer.new()
	gallery_scroll.custom_minimum_size.y = 440
	gallery_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(gallery_scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	gallery_scroll.add_child(grid)
	for i: int in range(gallery_photos.size()):
		var entry: Dictionary = gallery_photos[i]
		var card := _card(grid)
		var image := TextureRect.new()
		image.texture = album.texture(entry,true)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(330,186)
		card.add_child(image)
		_button(card,_photo_caption(entry),show_photo.bind(i))
	_actions("← 主菜单",show_home)


func _photo_caption(entry: Dictionary) -> String:
	var stage := RallyContentCatalog.stage(str(entry.get("stage","sunset_ridge")))
	return (stage.title if stage!=null else "赛道")+" / %s · %d PS"%[entry.get("vehicle",""),entry.get("power_ps",0)]


func show_photo(index: int) -> void:
	if gallery_photos.is_empty():
		show_gallery()
		return
	index = posmod(index,gallery_photos.size())
	var entry: Dictionary = gallery_photos[index]
	_page("%02d / %02d"%[index+1,gallery_photos.size()],_photo_caption(entry), "photo")
	var image := TextureRect.new()
	image.texture = album.texture(entry)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(800,430)
	column.add_child(image)
	var actions := _actions("← 相册",show_gallery,"下一张 →",show_photo.bind(index+1))
	var previous := _button(actions,"上一张",show_photo.bind(index-1))
	previous.custom_minimum_size = Vector2(130,40)
	previous.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	actions.move_child(previous,1)


func show_records() -> void:
	_page("你的山野足迹",RallyContentCatalog.POWER_LABELS[chosen_power_tier]+" · 每个赛道、车型和动力版本分别保存纪录与幽灵。","records")
	var tiers := _row(column)
	for tier: int in range(profile.unlocked_power_tier()+1):
		var option := _button(tiers,RallyContentCatalog.POWER_LABELS[tier],func(): chosen_power_tier=tier; show_records())
		RallySelectionStyle.apply(option,tier==chosen_power_tier)
	var bronze := 0
	var gold := 0
	for id: String in RallyContentCatalog.STAGES:
		_label(column,RallyContentCatalog.stage(id).title,25)
		var row := _row(column)
		for car: String in RallyContentCatalog.VEHICLES:
			var challenge := RallyContentCatalog.challenge(id,car,chosen_power_tier)
			var result := profile.result_for(challenge.key())
			var medal := int(result.get("medal",0))
			if medal>0: bronze+=1
			if medal==3: gold+=1
			var card := _card(row)
			_label(card,car+" / "+RallyContentCatalog.power_label(car,chosen_power_tier)+" · "+MEDALS[medal],20)
			_label(card,_time(result.best.total_time) if result.has("best") else "等待你的第一条轨迹",18)
	_label(column,"全金达成 · 每一段旅途都留下了金色轨迹！" if gold==9 else ("基础挑战完成 · 九枚奖牌，九段旅途。" if bronze==9 else "基础挑战 %d / 9    金牌 %d / 9"%[bronze,gold]),21,Color("efbf6e"))
	_actions("← 主菜单",show_home)


func show_tutorial() -> void:
	practice = true
	tutorial = true
	chosen_stage = "sunset_ridge"
	chosen_vehicle = "F160"
	chosen_power_tier = 0
	_page("先熟悉你的车","一段可随时跳过的小练习，使用夕照松岭的起点。","tutorial")
	_label(column,"加速与制动 → 转向 → 路书 → 恢复车辆\n\nW / S，A / D，R；或手柄扳机、左摇杆、Y。\n正式比赛需要完整通过检查点；恢复会增加罚时。",24)
	_actions("跳过，直接开始挑战",func(): tutorial=false; practice=false; show_stages(),"开始教学",start_race).primary_button.grab_focus()


func show_settings() -> void:
	_page("设置","", "settings")
	var identity := _row(column)
	var current_plate := RallyPlatePreview.new()
	current_plate.text = str(profile.data.get("plate",""))
	current_plate.custom_minimum_size = Vector2(240,48)
	identity.add_child(current_plate)
	_button(identity,"修改车牌",func(): show_plate_setup(false))
	_button(identity,"按键映射",show_bindings)
	var categories := RallySettingsPanel.new()
	column.add_child(categories)
	categories.build(prefs,350)
	categories.tabs[0].grab_focus()
	categories.setting_changed.connect(func(key: String,value: Variant): prefs.set_value(key,value); audio.apply_settings(prefs); _save())
	categories.voice_preview.connect(func(): audio.speak_note("preview",true))
	var footer := _row(column)
	var outputs := OptionButton.new()
	outputs.tooltip_text = "音频输出设备"
	for device: String in AudioServer.get_output_device_list():
		outputs.add_item(device)
		if device==AudioServer.output_device: outputs.select(outputs.item_count-1)
	outputs.item_selected.connect(func(index: int): AudioServer.output_device=outputs.get_item_text(index); profile.data["output_device"]=AudioServer.output_device; _save())
	footer.add_child(outputs)
	_button(footer,"试听提示音",func(): audio.cue("start"))
	_button(footer,"恢复默认",func(): prefs.reset(); profile.data.bindings={}; audio.apply_settings(prefs); _save(); show_settings())
	_actions("← 主菜单",show_home,"完成设置",show_home)


func show_plate_setup(first_use: bool = false) -> void:
	_page("为你的赛车签个名。" if first_use else "你的专属车牌", "设置一次，驶向每一段旅程。" if first_use else "保存后应用到选车预览与之后的比赛。", "plate")
	var row := _row(column)
	row.add_theme_constant_override("separation",44)
	var editor := VBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation",14)
	row.add_child(editor)
	_label(editor,"01 / 车牌号码",15,Color("65746c"))
	plate_input = LineEdit.new()
	plate_input.max_length = RallyPlateText.MAX_LENGTH
	plate_input.text = str(profile.data.get("plate",""))
	plate_input.placeholder_text = "例如：沪A·RALLY"
	plate_input.custom_minimum_size = Vector2(400,76)
	plate_input.add_theme_font_override("font",RallyPlateText.font())
	plate_input.add_theme_font_size_override("font_size",32)
	plate_input.add_theme_color_override("font_color",Color("192d2b"))
	plate_input.add_theme_color_override("font_placeholder_color",Color("84918a"))
	plate_input.add_theme_color_override("caret_color",Color("ad4d36"))
	for state: String in ["normal","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("faf9f3")
		style.border_color = Color("ad4d36") if state == "focus" else Color("9ca79d")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.content_margin_left = 18
		style.content_margin_right = 18
		plate_input.add_theme_stylebox_override(state,style)
	editor.add_child(plate_input)
	var counter := _label(editor,"",14,Color("65746c"))
	_label(editor,"支持中文、字母和数字等可显示字符，最多 10 个。\n输入与实际车牌使用相同字体。",16,Color("65746c"))
	plate_error = _label(editor,"",16,Color("a03f2e"))
	var display := VBoxContainer.new()
	display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	display.add_theme_constant_override("separation",18)
	row.add_child(display)
	_label(display,"02 / 实际字样预览",15,Color("65746c"))
	plate_preview = RallyPlatePreview.new()
	plate_preview.custom_minimum_size = Vector2(400,112)
	display.add_child(plate_preview)
	var buttons := _actions("" if first_use else "← 返回设置",show_settings,"保存并进入游戏" if first_use else "保存车牌",func(): _submit_plate(first_use))
	var submit := buttons.primary_button
	var update := func(value: String):
		counter.text = "%d / %d" % [value.length(),RallyPlateText.MAX_LENGTH]
		var valid := RallyPlateText.valid(value.strip_edges())
		plate_preview.text = value.strip_edges() if valid else RallyPlateText.DEFAULT_TEXT
		plate_error.text = "请输入 1–10 个可显示字符。" if not valid and not value.is_empty() else ""
		submit.disabled = not valid
	plate_input.text_changed.connect(update)
	plate_input.text_submitted.connect(func(_value: String): if not submit.disabled: _submit_plate(first_use))
	update.call(plate_input.text)
	plate_input.grab_focus()


func _submit_plate(first_use: bool) -> void:
	var value := plate_input.text.strip_edges()
	if not RallyPlateText.valid(value):
		plate_error.text = "请输入 1–10 个可显示字符。"
		return
	if profile.set_plate(value) != OK:
		plate_error.text = "车牌保存失败，原设置已保留。请检查磁盘空间和权限。"
		if first_use and not plate_error.has_meta("temporary_button"):
			plate_error.set_meta("temporary_button",true)
			_actions("",Callable(),"先使用此车牌，继续游戏",_use_plate_temporarily)
		return
	if first_use: show_home()
	else: show_settings()


func _use_plate_temporarily() -> void:
	var value := plate_input.text.strip_edges()
	if not RallyPlateText.valid(value):
		plate_error.text = "请输入 1–10 个可显示字符。"
		return
	profile.data["plate"] = value
	profile.message = "车牌尚未保存，退出后可能需要重新设置。"
	show_home()


func show_bindings() -> void:
	_page("键盘按键映射","点击操作后按新按键；Esc 取消。方向键始终可用。","bindings")
	var grid := GridContainer.new()
	grid.columns = 3
	column.add_child(grid)
	for entry: Array in [[KEY_W,"加速"],[KEY_S,"制动"],[KEY_A,"左转"],[KEY_D,"右转"],[KEY_SPACE,"手刹"],[KEY_R,"恢复"],[KEY_C,"镜头"],[KEY_Q,"降挡"],[KEY_E,"升挡"]]:
		var key := str(entry[0])
		var button := _button(grid,entry[1]+"  "+OS.get_keycode_string(int(profile.data.bindings.get(key,entry[0]))),func(): pass)
		button.set_meta("focus_key","binding:"+key)
		button.pressed.connect(func(): binding_wait=key; binding_button=button; button.text="请按新按键…")
	_actions("← 设置",show_settings,"完成映射",show_settings)


func _input(event: InputEvent) -> void:
	if screen=="replay" and ((event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>.5)):
		var waking: bool = not immersive_ui.get_child(0).visible
		immersive_idle=0
		immersive_ui.get_child(0).show()
		if get_viewport().gui_get_focus_owner()==null: replay_buttons[-1].grab_focus()
		if waking and event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			return
	if screen=="replay" and event is InputEventMouseMotion: immersive_idle = 0
	if screen in ["results","replay"] and is_instance_valid(race) and race.replay!=null and race.replay.active and event is InputEventKey and event.pressed and not event.echo:
		immersive_idle = 0
		match event.physical_keycode:
			KEY_SPACE: race.replay.playing = not race.replay.playing
			KEY_C: race.replay.set_camera(race.replay.mode+1)
			KEY_LEFT: race.replay.seek(race.replay.clock-5)
			KEY_RIGHT: race.replay.seek(race.replay.clock+5)
			KEY_ESCAPE:
				if screen!="replay": return
				_set_immersive(false)
			_: return
		get_viewport().set_input_as_handled()
		return
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
	_label(column,"引擎：Godot Engine / Jolt Physics\n车辆、风景、涂装：Art Rally 原创低多边形设计\n音效与音乐：项目原创合成
中文领航：Kokoro 合成语音，全部离线打包\n字体与依赖许可：见随包 ASSET_CREDITS.md\n\n感谢每一位试驾并留下反馈的玩家。",24)
	_label(column,"0.3.0 · 离线计时拉力 · 本地成绩与个人幽灵",16)
	_actions("← 主菜单",show_home)


func _save() -> void:
	profile.data.settings = prefs.values.duplicate()
	if profile.save_file()!=OK and is_instance_valid(column): _label(column,profile.message,16,Color("ffd38b"))


static func _time(seconds: float) -> String:
	return "%02d:%05.2f"%[int(seconds)/60,fmod(seconds,60)]


func _restore_page_focus(expected: String) -> void:
	if screen!=expected or not is_instance_valid(ui) or not ui.visible: return
	var candidates := RallyMenuInput.focusable(ui)
	var saved := str(focus_memory.get(screen,""))
	if not saved.is_empty():
		for control: Control in candidates:
			if RallyMenuInput.token(control)==saved:
				control.grab_focus()
				return
	var focus := get_viewport().gui_get_focus_owner()
	if focus!=null and ui.is_ancestor_of(focus): return
	if not candidates.is_empty(): candidates[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo(): return
	if loading or transitions.busy or transitions.wipe.visible: return
	if screen=="race": return # The visible pause menu owns cancel during driving.
	if not binding_wait.is_empty():
		binding_wait=""
		show_bindings()
	elif screen=="replay":
		_set_immersive(false)
	elif page_back.is_valid():
		audio.cue("ui")
		page_back.call()
	else:
		return
	get_viewport().set_input_as_handled()


func _quit_game() -> void:
	audio.set_process(false)
	audio.stop_all()
	await get_tree().create_timer(.12).timeout
	get_tree().quit()

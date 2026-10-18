class_name RallyPauseMenu
extends CanvasLayer

signal resume_requested
signal restart_requested
signal practice_requested
signal setting_changed(key: String,value: Variant)
signal defaults_requested
signal vehicle_requested
signal autopilot_changed(mode: String)
var prefs: RallyGameSettings
var widgets: Dictionary = {}
var resume_button: Button
var message: Label
var autopilot_selector: OptionButton


func build(settings: RallyGameSettings) -> void:
	prefs = settings
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.03,0.025,0.73)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(530,540)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("19362c")
	style.border_color = Color("d5a25d")
	style.border_width_top = 3
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var theme := Theme.new()
	theme.default_font = RallyFonts.TEXT
	theme.default_font_size = 15
	theme.set_color("font_color","Label",Color("eee7d4"))
	for state: String in ["normal","hover","pressed","focus"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("355647") if state!="normal" else Color("243e33")
		button_style.border_color = Color("e8ac59")
		button_style.border_width_bottom = 2 if state=="focus" else 0
		button_style.content_margin_top = 7
		button_style.content_margin_bottom = 7
		theme.set_stylebox(state,"Button",button_style)
	panel.theme = theme
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "ART / RALLY     暂停与设置"
	title.add_theme_font_override("font",RallyFonts.bold())
	title.add_theme_font_size_override("font_size",23)
	column.add_child(title)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	resume_button = button(buttons,"继续驾驶",func(): resume_requested.emit())
	button(buttons,"重跑赛段",func(): restart_requested.emit())
	button(buttons,"计时 / 练习",func(): practice_requested.emit())
	button(column,"更换车辆（确认后重开赛段）",func(): vehicle_requested.emit())
	var auto_row := HBoxContainer.new()
	column.add_child(auto_row)
	var auto_label := Label.new()
	auto_label.text = "自动驾驶"
	auto_label.custom_minimum_size.x = 165
	auto_row.add_child(auto_label)
	autopilot_selector = OptionButton.new()
	autopilot_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option_title: String in ["关闭（真人驾驶）","虚拟键盘","虚拟手柄"]:
		autopilot_selector.add_item(option_title)
	autopilot_selector.item_selected.connect(func(index: int): autopilot_changed.emit(["off","vkeyboard","vgamepad"][index]))
	auto_row.add_child(autopilot_selector)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(475,clampf(get_viewport().get_visible_rect().size.y-310,180,335))
	panel.custom_minimum_size.y = 0
	root.resized.connect(func(): scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y-310,180,335))
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	for entry: Array in [["volume","声音音量"],["engine_volume","发动机"],["road_volume","路面"],["environment_volume","环境"],["interface_volume","界面提示"],["music_volume","菜单音乐"],["steering_response","键盘转向响应"],["return_rate","键盘回正速度"],["throttle_rise","油门建立时间"],["brake_rise","制动建立时间"],["stick_deadzone","手柄摇杆死区"],["brake_bias","前轮制动比例"],["spring_scale","悬架弹簧倍率"],["tire_visual_gain","轮胎形变显示倍率"]]:
		var row := HBoxContainer.new()
		list.add_child(row)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size.x = 165
		row.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 215
		slider.min_value = RallyGameSettings.RANGES[entry[0]].x
		slider.max_value = RallyGameSettings.RANGES[entry[0]].y
		slider.step = 0.01
		slider.value = prefs.values[entry[0]]
		row.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 48
		value.text = "%.2f"%slider.value
		row.add_child(value)
		slider.value_changed.connect(_slider_changed.bind(entry[0],value))
		widgets[entry[0]] = slider
	for entry: Array in [["ghost","个人幽灵"],["lens_flare","镜头光斑"],["camera_motion","驾驶舱轻微震动"],["automatic","自动换挡"],["reverse_assist","停稳刹车 3 秒自动挂倒挡"],["keyboard_light","键盘轻辅助（更直接）"],["vibration","手柄震动"],["low_detail","低细节（减少草簇和散石）"]]:
		var toggle := CheckButton.new()
		toggle.text = entry[1]
		toggle.button_pressed = prefs.values[entry[0]]
		toggle.toggled.connect(_toggle_changed.bind(entry[0]))
		list.add_child(toggle)
		widgets[entry[0]] = toggle
	button(column,"恢复默认设置",func(): defaults_requested.emit(); sync())
	message = Label.new()
	message.text = "设置保存在本机 · F10 切换自动驾驶 · Esc / Start 继续"
	message.add_theme_font_size_override("font_size",12)
	column.add_child(message)
	visible = false


func button(parent: Node,title: String,action: Callable) -> Button:
	var result := Button.new()
	result.text = title
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.pressed.connect(action)
	parent.add_child(result)
	return result


func _slider_changed(value: float,key: String,label: Label) -> void:
	label.text = "%.2f"%value
	setting_changed.emit(key,value)


func _toggle_changed(value: bool,key: String) -> void:
	setting_changed.emit(key,value)


func sync() -> void:
	for key: String in widgets:
		var widget: Control = widgets[key]
		if widget is Slider:
			widget.set_value_no_signal(prefs.values[key])
			widget.get_parent().get_child(2).text = "%.2f"%prefs.values[key]
		else: widget.set_pressed_no_signal(prefs.values[key])


func set_autopilot_mode(mode: String) -> void:
	if not is_instance_valid(autopilot_selector): return
	autopilot_selector.select(maxi(0,["off","vkeyboard","vgamepad"].find(mode)))


func show_menu(value: bool) -> void:
	visible = value
	if value:
		sync()
		resume_button.grab_focus()
	else:
		var focus := get_viewport().gui_get_focus_owner()
		if focus!=null: focus.release_focus()

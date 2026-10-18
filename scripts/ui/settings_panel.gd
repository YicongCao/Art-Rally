class_name RallySettingsPanel
extends HBoxContainer

signal setting_changed(key: String,value: Variant)
signal voice_preview
var prefs: RallyGameSettings
var widgets: Dictionary = {}
var pages: Array[Control] = []
var tabs: Array[Button] = []
const CATEGORIES := [["驾驶","settings_drive"],["画面与显示","settings_display"],["声音与领航","settings_audio"],["机械调校","settings_tuning"]]
const SLIDERS := [
	[["steering_response","转向响应"],["return_rate","回正速度"],["throttle_rise","油门响应"],["brake_rise","制动响应"],["stick_deadzone","摇杆死区"]],
	[["tire_visual_gain","轮胎形变"]],
	[["volume","总音量"],["engine_volume","发动机"],["road_volume","轮胎与路面"],["environment_volume","环境"],["interface_volume","界面提示"],["music_volume","音乐"],["voice_volume","语音路书"]],
	[["brake_bias","前轮制动比例"],["spring_scale","悬架弹簧"]]]
const TOGGLES := [
	[["automatic","自动换挡"],["reverse_assist","停稳制动挂倒挡"],["keyboard_light","键盘辅助"],["vibration","手柄震动"]],
	[["ghost","个人幽灵"],["show_fps","显示帧率"],["low_detail","简化植被"],["camera_motion","驾驶舱震动"],["lens_flare","镜头光斑"]],[],[]]

func build(settings: RallyGameSettings,height: float = 330) -> void:
	prefs = settings
	add_theme_constant_override("separation",24)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 165
	nav.add_theme_constant_override("separation",8)
	add_child(nav)
	var content := PanelContainer.new()
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(.035,.085,.075,.86)
	surface.content_margin_left = 18
	surface.content_margin_right = 18
	surface.content_margin_top = 10
	surface.content_margin_bottom = 10
	content.add_theme_stylebox_override("panel",surface)
	content.custom_minimum_size = Vector2(440,height)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)
	for i: int in range(CATEGORIES.size()):
		var tab := Button.new()
		tab.text = CATEGORIES[i][0]
		tab.custom_minimum_size = Vector2(160,52)
		tab.pressed.connect(select.bind(i))
		nav.add_child(tab)
		tabs.append(tab)
		var scroll := ScrollContainer.new()
		scroll.follow_focus = true
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(scroll)
		pages.append(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation",12)
		scroll.add_child(list)
		for entry: Array in TOGGLES[i]:
			var toggle := CheckButton.new()
			toggle.text = entry[1]
			toggle.button_pressed = prefs.values[entry[0]]
			toggle.toggled.connect(func(value: bool): setting_changed.emit(entry[0],value))
			list.add_child(toggle)
			widgets[entry[0]] = toggle
		for entry: Array in SLIDERS[i]: _slider(list,entry)
		if i==2:
			var row := HBoxContainer.new()
			list.add_child(row)
			var label := Label.new()
			label.text = "领航员"
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var voice := OptionButton.new()
			for title: String in ["女声 · 清亮","男声 · 沉稳","关闭"]: voice.add_item(title)
			voice.select(["female","male","off"].find(prefs.values.voice))
			voice.item_selected.connect(func(index: int): setting_changed.emit("voice",["female","male","off"][index]))
			row.add_child(voice)
			widgets["voice"] = voice
			var preview := Button.new()
			preview.text = "试听领航"
			preview.pressed.connect(func(): voice_preview.emit())
			row.add_child(preview)
		if i==3:
			var note := Label.new()
			note.text = "仅自由练习可调整，计时挑战使用统一标定。"
			note.add_theme_font_size_override("font_size",13)
			list.add_child(note)
	select(0)

func _slider(parent: Node,entry: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = entry[1]
	label.custom_minimum_size.x = 145
	row.add_child(label)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 160
	slider.min_value = RallyGameSettings.RANGES[entry[0]].x
	slider.max_value = RallyGameSettings.RANGES[entry[0]].y
	slider.step = .01
	slider.value = prefs.values[entry[0]]
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size.x = 48
	value.text = "%.2f"%slider.value
	row.add_child(value)
	slider.value_changed.connect(func(number: float): value.text="%.2f"%number; setting_changed.emit(entry[0],number))
	widgets[entry[0]] = slider

func select(index: int) -> void:
	for i: int in range(pages.size()):
		pages[i].visible = i==index
		RallySelectionStyle.apply(tabs[i],i==index)
		tabs[i].icon = load("res://assets/ui/icons/"+CATEGORIES[i][1]+".svg")

func sync() -> void:
	for key: String in widgets:
		var widget: Control = widgets[key]
		if widget is Slider:
			widget.set_value_no_signal(prefs.values[key])
			widget.get_parent().get_child(2).text = "%.2f"%prefs.values[key]
		elif widget is OptionButton: widget.select(["female","male","off"].find(prefs.values.voice))
		else: widget.set_pressed_no_signal(prefs.values[key])

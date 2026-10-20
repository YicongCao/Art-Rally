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
var actions: RallyActionBar
var categories: RallySettingsPanel
signal voice_preview


func build(settings: RallyGameSettings) -> void:
	RallyMenuInput.install()
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
	panel.custom_minimum_size = Vector2(760,540)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20252b")
	style.border_color = Color("d5a25d")
	style.border_width_top = 3
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var theme := RallyScreenprintStyle.theme()
	panel.theme = theme
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "BRUSHLINE RALLY     暂停与设置"
	title.add_theme_font_override("font",RallyFonts.bold())
	title.add_theme_font_size_override("font_size",23)
	column.add_child(title)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	button(buttons,"重跑赛段",func(): restart_requested.emit())
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
	categories = RallySettingsPanel.new()
	column.add_child(categories)
	categories.build(prefs,clampf(get_viewport().get_visible_rect().size.y-370,180,300))
	categories.setting_changed.connect(func(key: String,value: Variant): setting_changed.emit(key,value))
	categories.voice_preview.connect(func(): voice_preview.emit())
	widgets = categories.widgets
	button(column,"恢复默认设置",func(): defaults_requested.emit(); sync())
	message = Label.new()
	message.text = "设置保存在本机 · F10 切换自动驾驶 · Esc / Start 继续"
	message.add_theme_font_size_override("font_size",12)
	column.add_child(message)
	actions = RallyActionBar.create(column,"",Callable(),"继续驾驶 →",func(): resume_requested.emit(),true)
	resume_button = actions.primary_button
	visible = false


func button(parent: Node,title: String,action: Callable) -> Button:
	var result := Button.new()
	result.text = title
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.pressed.connect(action)
	parent.add_child(result)
	return result


func sync() -> void:
	categories.sync()


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


func _unhandled_input(event: InputEvent) -> void:
	# Popup menus receive cancel first. ESC/Start remain owned by driving input.
	if visible and event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()

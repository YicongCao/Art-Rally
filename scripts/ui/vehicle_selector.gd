class_name RallyVehicleSelector
extends CanvasLayer

signal confirmed(layout: String)
signal cancelled
var selected: String = "AWD"
var allow_cancel: bool = false
var cards: Dictionary = {}
var start_button: Button
var cancel_button: Button


func build() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.035,0.025,0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("19362c")
	style.border_width_top = 3
	style.border_color = Color("e8ac59")
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC","Noto Sans CJK SC"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color","Label",Color("eee7d4"))
	for state: String in ["normal","hover","pressed","focus"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("345c48") if state in ["hover","pressed"] else Color("102a22")
		button_style.border_color = Color("e8ac59")
		button_style.set_border_width_all(2 if state in ["pressed","focus"] else 0)
		button_style.content_margin_top = 12
		button_style.content_margin_bottom = 12
		theme.set_stylebox(state,"Button",button_style)
	panel.theme = theme
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	panel.add_child(column)
	var title := Label.new()
	title.text = "ART / RALLY    选择驱动方式"
	title.add_theme_font_size_override("font_size",26)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "夕照松岭 / 3.05 km / 16:00"
	column.add_child(subtitle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	var group := ButtonGroup.new()
	for entry: Array in [["FWD","前轮驱动","更留意出弯推头"],["AWD","四轮驱动","当前默认基线"],["RWD","后轮驱动","油门控制车尾"]]:
		var card := Button.new()
		card.text = "%s\n%s\n\n%s"%entry
		card.custom_minimum_size = Vector2(174,148)
		card.toggle_mode = true
		card.button_group = group
		card.pressed.connect(_select.bind(entry[0]))
		row.add_child(card)
		cards[entry[0]] = card
	var info := Label.new()
	info.text = "共用车身、重心与动力参数，仅改变驱动轴。\n停稳持续刹车 3 秒 → 倒挡；S/↓ 倒车，W/↑ 前进。"
	info.add_theme_font_size_override("font_size",14)
	column.add_child(info)
	start_button = Button.new()
	start_button.text = "开始新赛段  /  Enter · Start"
	start_button.pressed.connect(func(): confirmed.emit(selected))
	column.add_child(start_button)
	cancel_button = Button.new()
	cancel_button.text = "返回设置"
	cancel_button.pressed.connect(func(): cancelled.emit())
	column.add_child(cancel_button)
	visible = false


func _select(layout: String) -> void:
	selected = layout
	start_button.grab_focus()


func open(layout: String,can_cancel: bool = false) -> void:
	selected = layout if layout in ["FWD","AWD","RWD"] else "AWD"
	allow_cancel = can_cancel
	cards[selected].set_pressed_no_signal(true)
	cancel_button.visible = can_cancel
	visible = true
	start_button.grab_focus()


func close() -> void:
	visible = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus!=null: focus.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START:
		confirmed.emit(selected)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE and allow_cancel:
		cancelled.emit()
		get_viewport().set_input_as_handled()

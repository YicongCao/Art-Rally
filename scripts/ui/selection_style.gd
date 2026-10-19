class_name RallySelectionStyle
extends RefCounted

static func apply(button: Button,selected: bool) -> void:
	button.toggle_mode = true
	button.set_pressed_no_signal(selected)
	button.set_meta("selected",selected)
	RallyRacingPatina.select_mark(button,selected)
	button.icon = load("res://assets/ui/icons/check.svg") if selected else null
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width",18)
	button.add_theme_constant_override("h_separation",7)
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("d6a83c") if selected else Color("246263")
		if state in ["hover","hover_pressed"]: style.bg_color = style.bg_color.lightened(.10)
		style.border_color = Color("eee2c5") if selected else Color("847f88")
		style.set_border_width_all(2 if selected else 1)
		if state=="focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("a3d9e4")
			style.set_border_width_all(3)
		if state=="disabled":
			style.bg_color = Color("282b32")
			style.border_color = Color("3f5149")
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state,style)
		var ink := Color("20252b") if selected else Color("eee2c5")
		if state=="disabled": ink = Color("8c9a90")
		button.add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",ink)
		button.add_theme_color_override("icon_normal_color" if state=="normal" else "icon_"+state+"_color",ink)

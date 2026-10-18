class_name RallyActionBar
extends HBoxContainer

var primary_button: Button
var back_button: Button


static func create(parent: Node,back_title: String,back: Callable,confirm_title: String = "",confirm: Callable = Callable(),compact: bool = false) -> RallyActionBar:
	var bar := RallyActionBar.new()
	bar.add_theme_constant_override("separation",14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bar)
	if not back_title.is_empty(): bar.add_back(back_title,back,compact)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(space)
	if not confirm_title.is_empty():
		var button := Button.new()
		button.text = confirm_title
		button.custom_minimum_size = Vector2(230,54) if compact else Vector2(320,60)
		button.add_theme_font_size_override("font_size",20 if compact else 22)
		button.add_theme_font_override("font",RallyFonts.bold())
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.set_meta("action_role","confirm")
		button.pressed.connect(confirm)
		bar.add_child(button)
		bar.primary_button = button
	return bar


func add_back(title: String,action: Callable,compact: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(150,38) if compact else Vector2(184,40)
	button.add_theme_font_size_override("font_size",15 if compact else 16)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.set_meta("action_role","back")
	button.pressed.connect(action)
	add_child(button)
	move_child(button,0)
	back_button = button
	return button

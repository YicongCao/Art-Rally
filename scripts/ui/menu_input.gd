class_name RallyMenuInput
extends RefCounted

# Godot's platform defaults do not always include joypad accept/cancel.
# Add only missing events, preserving keyboard actions and all controller IDs.
static func install() -> void:
	for entry: Array in [["ui_accept",JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_B]]:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = entry[1]
		if not InputMap.action_has_event(entry[0],event): InputMap.action_add_event(entry[0],event)

static func focusable(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in root.get_children():
		if child is Control and child.is_visible_in_tree():
			if child.focus_mode==Control.FOCUS_ALL and not (child is BaseButton and child.disabled): result.append(child)
			result.append_array(focusable(child))
	return result

static func token(control: Control) -> String:
	if control.has_meta("focus_key"): return str(control.get_meta("focus_key"))
	if control is Button: return control.text
	return ""

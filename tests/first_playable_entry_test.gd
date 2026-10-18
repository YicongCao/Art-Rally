extends "res://tests/test_suite.gd"

var app: RallyGameApp


func _run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/game/game.tscn", "Default player entry is the full game")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await process_frame
	await process_frame
	app = current_scene as RallyGameApp
	check(app != null, "Configured main scene creates the game front end")
	if app == null:
		finish()
		return
	await settled()
	check(app.screen == "home" and app.ui.is_visible_in_tree(), "Player sees the title menu on normal startup")
	check(visible_button("开始计时挑战  →") != null and visible_button("设置与声音试听") != null, "Challenge and settings buttons occupy the visible viewport")
	await capture("home")
	visible_button("开始计时挑战  →").pressed.emit()
	await settled()
	check(app.screen == "stages" and app.ui.find_children("*", "Button", true, false).size() == 4, "Challenge button opens all three stage choices")
	await capture("stages")
	visible_button("选择赛段 →").pressed.emit()
	await settled()
	check(app.screen == "vehicles" and visible_button("驾驶 F160") != null and visible_button("驾驶 R200") != null and visible_button("驾驶 A240") != null, "Stage selection opens three visible vehicle choices")
	await capture("vehicles")
	app.show_home()
	await settled()
	visible_button("设置与声音试听").pressed.emit()
	await settled()
	check(app.screen == "settings" and app.ui.is_visible_in_tree(), "Settings opens through the title menu")
	await capture("settings")
	app.show_home()
	await settled()
	check(visible_button("开始计时挑战  →") != null, "Returning to title restores usable controls")
	app.free()
	await process_frame
	finish()


func settled() -> void:
	for i: int in range(4): await process_frame


func visible_button(text: String) -> Button:
	for node: Node in app.ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree() and button.get_global_rect().intersects(Rect2(Vector2.ZERO, root.get_visible_rect().size)):
			return button
	return null


func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/player-entry-" + label + ".jpg", .9)

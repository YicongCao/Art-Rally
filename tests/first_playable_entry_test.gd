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
	# Onboarding itself is exercised with an isolated profile in plate_identity_test.
	if app.screen == "plate": app.show_home()
	await settled()
	check(app.screen == "home" and app.ui.is_visible_in_tree(), "Player sees the title menu on normal startup")
	check(visible_button("开始计时挑战") != null and visible_button("设置") != null, "Challenge and settings buttons occupy the visible viewport")
	check(visible_button("开始计时挑战").size.y > visible_button("成绩册").size.y * 2, "Frequent actions have larger tiles than secondary actions")
	var icons := app.ui.find_children("*", "TextureRect", true, false)
	icons = icons.filter(func(icon: TextureRect): return icon.texture != null and icon.texture.resource_path.begins_with("res://assets/ui/icons/"))
	check(icons.size() == 9, "All nine menu actions have loaded vector icons")
	check(not visible_button("开始计时挑战").get_global_rect().intersects(visible_button("设置").get_global_rect()), "Primary tiles have separate hit targets")
	check(visible_button("开始计时挑战").position.x < visible_button("玩法演示").position.x and visible_button("玩法演示").position.x < visible_button("设置").position.x,"Primary menu order is challenge, demo, settings")
	await capture("home")
	click_button(visible_button("开始计时挑战"))
	await settled()
	check(app.screen == "stages" and app.ui.find_children("*", "Button", true, false).size() == RallyContentCatalog.STAGES.size()+2, "Challenge button opens all stage choices with separate confirmation")
	await capture("stages")
	click_button(visible_button("确认赛道 →"))
	await settled()
	check(app.screen == "vehicles" and not app.ui.find_children("*", "Button", true, false).filter(func(b: Button): return b.text.begins_with("驾驶 ")).is_empty() and app.ui.find_children("*", "Button", true, false).filter(func(b: Button): return b.has_meta("power_tier")).size() == 9, "Stage confirmation opens three vehicles with a separate confirmation")
	await capture("vehicles")
	app.show_home()
	await settled()
	click_button(visible_button("设置"))
	await settled()
	check(app.screen == "settings" and app.ui.is_visible_in_tree(), "Settings opens through the title menu")
	await capture("settings")
	app.show_home()
	await settled()
	check(visible_button("开始计时挑战") != null, "Returning to title restores usable controls")
	app.free()
	await process_frame
	finish()


func settled() -> void:
	if DisplayServer.get_name()!="headless": await create_timer(.25).timeout
	for i: int in range(4): await process_frame


func visible_button(text: String) -> Button:
	for node: Node in app.ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree() and button.get_global_rect().intersects(Rect2(Vector2.ZERO, root.get_visible_rect().size)):
			return button
	return null


func click_button(button: Button) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		root.push_input(event,true)


func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/previews/player-entry-" + label + ".jpg", .9)

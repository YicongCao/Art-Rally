extends "res://tests/test_suite.gd"


func _run() -> void:
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	var pages: Array[Callable] = [app.show_stages,app.show_vehicles,app.show_briefing,app.show_tutorial,app.show_settings,app.show_bindings,app.show_records,app.show_credits,app.show_plate_setup.bind(false)]
	for page: Callable in pages:
		page.call()
		for i: int in range(4): await process_frame
		var bars := app.ui.find_children("*","HBoxContainer",true,false).filter(func(row: HBoxContainer): return row is RallyActionBar)
		check(not bars.is_empty(),app.screen+" uses the common action layout")
		for row: RallyActionBar in bars:
			if row.back_button != null:
				check(row.back_button.get_global_rect().get_center().x < app.ui.size.x*.4,app.screen+" back action stays on the left")
			if row.primary_button != null:
				check(row.primary_button.get_global_rect().get_center().x > app.ui.size.x*.6,app.screen+" confirmation stays on the right")
				if app.screen in ["stages","vehicles","briefing"]:
					check(row.primary_button.get_global_rect().end.y <= root.get_visible_rect().size.y-20,app.screen+" confirmation fits without scrolling")
				if row.back_button != null:
					check(row.primary_button.size.y>row.back_button.size.y and row.primary_button.size.x>row.back_button.size.x,app.screen+" confirmation is larger than back")
	app.free()
	await process_frame
	finish()

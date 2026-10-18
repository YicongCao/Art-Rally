extends "res://tests/test_suite.gd"


func _run() -> void:
	check(RallyPlateText.valid("RALLY-0160"), "Ten visible characters fit the plate limit")
	check(RallyPlateText.valid("沪A·山野拉力"), "Chinese and Latin characters use the bundled plate font")
	check(not RallyPlateText.valid("RALLY-01601"), "Eleven characters are rejected by storage validation")
	check(not RallyPlateText.valid("") and not RallyPlateText.valid("   "), "Empty identity cannot complete onboarding")
	check(not RallyPlateText.valid("RALLY\n160") and not RallyPlateText.valid("A\u200bB"), "Control and invisible characters cannot enter plates")
	var legacy := RallyProfileStore.fresh()
	legacy.erase("plate")
	check(RallyProfileStore.valid(legacy), "Existing profiles without a plate remain compatible")
	var directory := "user://plate-test-" + str(Time.get_ticks_usec())
	var store := RallyProfileStore.new()
	store.path = directory + "/profile.json"
	check(store.set_plate(" 沪A·RALLY ") == OK and store.data.plate == "沪A·RALLY", "Saving normalizes outer spaces and keeps the chosen identity")
	var restored := RallyProfileStore.new()
	restored.path = store.path
	check(restored.load_file() == OK and restored.data.plate == "沪A·RALLY", "Restart restores the chosen plate")
	var before := restored.data.duplicate(true)
	check(restored.set_plate("12345678901") != OK and restored.data == before, "Rejected length cannot alter the saved profile")
	var blocker := FileAccess.open(directory + "/blocked", FileAccess.WRITE)
	blocker.store_string("not a directory")
	blocker.close()
	restored.path = directory + "/blocked/profile.json"
	check(restored.set_plate("NEW-160") != OK and restored.data == before, "A save failure preserves the previous plate")
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	app.profile.path = directory + "/first-use.json"
	root.add_child(app)
	await settled()
	check(app.screen == "plate", "A fresh player reaches plate setup before the main menu")
	check(app.plate_input.max_length == 10 and app.plate_input.get_theme_font("font") == RallyPlateText.font(), "Input shares the actual plate font and enforces the limit")
	app.plate_input.text = "沪A·RALLY"
	app.plate_input.text_changed.emit(app.plate_input.text)
	check(app.plate_preview.text == "沪A·RALLY", "Live preview follows the editor")
	app._submit_plate(true)
	await settled()
	check(app.screen == "home" and app.profile.data.plate == "沪A·RALLY", "Successful setup persists identity and opens the title menu")
	app.show_settings()
	check(app.ui.find_children("*", "Button", true, false).any(func(button: Button): return button.text == "修改车牌"), "Settings exposes plate editing")
	app.show_plate_setup(false)
	app.plate_input.text = "山野-160"
	app._submit_plate(false)
	await settled()
	check(app.screen == "settings" and app.profile.data.plate == "山野-160", "Editing saves the new identity and returns to settings")
	app._loading_page()
	await settled()
	var medal_icons := app.ui.find_children("*", "TextureRect", true, false).filter(func(icon: TextureRect): return icon.texture != null and icon.texture.resource_path.contains("/medal_"))
	check(medal_icons.size() == 3, "Swiss briefing loads all three vector medal icons")
	var clocks := app.ui.find_children("*", "Label", true, false).filter(func(label: Label): return label.text == app._time(RallyContentCatalog.challenge(app.chosen_stage,app.chosen_vehicle).thresholds()[2]))
	check(not clocks.is_empty() and clocks[0].size.x > 100 and clocks[0].size.y < 60, "Medal times retain a readable horizontal layout")
	var loading_text := " ".join(app.ui.find_children("*","Label",true,false).map(func(label: Label): return label.text))
	check(not loading_text.contains("罚时") and not loading_text.contains("检查点") and not loading_text.contains("有效挑战") and not loading_text.contains("暂定"),"Loading retains essentials without rule explanations")
	app.show_plate_setup(false)
	app.profile.read_only = true
	app.plate_input.text = "FAILED-160"
	app._submit_plate(false)
	check(app.screen == "plate" and not app.plate_error.text.is_empty() and app.profile.data.plate == "山野-160", "UI reports a failed save without applying the rejected edit")
	app.profile.read_only = false
	for id: String in RallyContentCatalog.VEHICLES:
		var body := Node3D.new()
		root.add_child(body)
		var plates := RallyVehiclePlate.attach(body,RallyContentCatalog.vehicle(id),"沪A·山野拉力016")
		check(plates.labels.size() == 2 and plates.labels.all(func(label: Label3D): return label.text == "沪A·山野拉力016" and label.font == RallyPlateText.font()), id + " has matching front and rear plates in the shared font")
		check(plates.labels[0].global_basis.z.z > .99 and plates.labels[1].global_basis.z.z < -.99, id + " plates face outward on both ends")
		for value: String in ["RALLY","WWWWWWWWWW","沪A·山野拉力016"]:
			plates.set_text(value)
			var face := RallyPlateText.font()
			var width := face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x
			var scale: float=plates.labels[0].pixel_size
			check(width*scale<=.70*.8+.00001 and face.get_height(64)*scale<=.17*.8+.00001,"Plate keeps at least ten percent inset: "+value)
			if value=="RALLY": check(is_equal_approx(scale,.105/face.get_height(64)*1.2),"Short plate type grows by twenty percent")
		check(plates.find_children("*", "CollisionObject3D", true, false).is_empty(), id + " identity adds no collision or physics body")
		body.free()
	app.free()
	await settled()
	var reentry: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	reentry.profile.path = directory + "/first-use.json"
	root.add_child(reentry)
	check(reentry.screen == "home" and reentry.profile.data.plate == "山野-160", "Configured players bypass onboarding after restart")
	reentry.free()
	for file: String in DirAccess.open(directory).get_files(): DirAccess.remove_absolute(directory + "/" + file)
	DirAccess.remove_absolute(directory)
	finish()


func settled() -> void:
	for i: int in range(4): await process_frame

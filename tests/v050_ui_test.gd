extends "res://tests/test_suite.gd"

func _run() -> void:
	var view := SubViewport.new()
	view.size=Vector2i(1280,720)
	view.handle_input_locally=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.texture=view.get_texture()
	root.add_child(display)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://v050-ui-%d/profile.json"%Time.get_ticks_usec()
	view.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.unlocked_power_tier=2
	app.prefs.values.reduced_motion=true
	AudioServer.set_bus_mute(0,true)
	for stage: String in RallyContentCatalog.STAGES:
		for car: String in RallyContentCatalog.VEHICLES:
			for tier: int in range(3):
				app.profile.data.challenges[RallyContentCatalog.challenge(stage,car,tier).key()]={"medal":3,"best":{"total_time":999.999}}
	for pixels: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		view.size=pixels
		check(view.size==pixels,"Requested render resolution is exact: %s"%pixels)
		for page: String in ["home","guide","records","credits"]:
			app.call("show_"+page)
			await create_timer(.25).timeout
			for i: int in range(5): await process_frame
			var bounds := Rect2(Vector2.ZERO,Vector2(pixels)).grow(-16)
			if page!="home": check(app.ui.find_children("*","ScrollContainer",true,false).is_empty(),"%s %d has no vertical scrolling"%[page,pixels.x])
			var buttons := {}
			for button: Button in app.ui.find_children("*","Button",true,false):
				if button.is_visible_in_tree():
					buttons[button.text]=button
					check(bounds.encloses(button.get_global_rect()),"%s %d: %s remains visible"%[page,pixels.x,button.text])
			if page=="home":
				check(buttons["玩法演示"].get_global_rect().position.y<buttons["自由练习"].get_global_rect().position.y,"Demo takes the primary row")
				check(buttons["玩法演示"].size.y>buttons["自由练习"].size.y,"Demo has the larger action tile")
			if page=="records":
				for tier: int in range(3):
					app.chosen_power_tier=tier
					app.show_records()
					for i: int in range(3): await process_frame
					check(bounds.encloses(app.column.get_global_rect()),"All records fit: %d tier %d"%[pixels.x,tier])
			if page=="guide":
				var diagrams: Array=app.ui.find_children("*","RallyControlGuide",true,false)
				check(diagrams.size()==2,"Keyboard and transparent gamepad diagrams present")
				for diagram: Control in diagrams: check(bounds.encloses(diagram.get_global_rect()),"Guide diagram fits on screen")
			if page=="credits":
				var text := ""
				for label: Label in app.ui.find_children("*","Label",true,false): text+=label.text+"\n"
				check(text.contains("Godot Engine") and text.contains("Jolt Physics") and text.count("Pixelcao")==2 and text.contains("合成语音") and text.contains("Codex"),"Credits match requested roles")
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				view.get_texture().get_image().save_png("res://docs/validation/v050/%s-%d.png"%[page,pixels.x])
		# Real GUI input to the visible back action.
		app.show_records()
		await create_timer(.25).timeout
		for i: int in range(3): await process_frame
		var back: Button=app.column.get_child(app.column.get_child_count()-1).back_button
		back.grab_focus()
		var event := InputEventJoypadButton.new()
		event.button_index=JOY_BUTTON_A
		event.pressed=true
		view.push_input(event)
		await process_frame
		event=event.duplicate()
		event.pressed=false
		view.push_input(event)
		await process_frame
		check(app.screen=="home","Visible records return button activates via gamepad GUI input")
	# Export the diagrams as reusable transparent PNGs, with live vector labels.
	if DisplayServer.get_name()!="headless":
		var art := SubViewport.new()
		art.size=Vector2i(1120,780)
		art.transparent_bg=true
		art.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(art)
		for pad: bool in [false,true]:
			var diagram := RallyControlGuide.new()
			diagram.gamepad=pad
			diagram.size=Vector2(1120,740)
			art.add_child(diagram)
			for i: int in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var captured := art.get_texture().get_image()
			check(captured.get_pixel(0,0).a==0,"Diagram background is transparent")
			captured.save_png("res://docs/validation/v050/%s-wireframe.png"%("controller" if pad else "keyboard"))
			diagram.free()
		art.free()
	app.transitions.finish_slide()
	await create_timer(.2).timeout
	app.free()
	display.texture=null
	view.free()
	await process_frame
	finish()

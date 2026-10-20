extends "res://tests/test_suite.gd"

var app: RallyGameApp

func settle() -> void:
	await create_timer(.28 if DisplayServer.get_name()!="headless" else .03).timeout

func press(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device=7 # Menu mappings must work for a reconnected/nonzero controller ID.
	event.button_index=button
	event.pressed=true
	root.push_input(event)
	await process_frame
	event=event.duplicate()
	event.pressed=false
	root.push_input(event)
	await settle()

func button_with(key: String) -> Control:
	for control: Control in RallyMenuInput.focusable(app.ui):
		if RallyMenuInput.token(control)==key: return control
	return null

func _run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://menu-pad-test-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="PAD TEST"
	app.profile.data.unlocked_stages=Array(RallyContentCatalog.STAGES)
	AudioServer.set_bus_mute(0,true)
	app.show_home()
	await settle()
	check(root.gui_get_focus_owner()!=null,"Title opens with a focused action")
	await press(JOY_BUTTON_A)
	check(app.screen=="stages","South button activates the actual GUI button")
	var prior := root.gui_get_focus_owner()
	await press(JOY_BUTTON_DPAD_UP)
	check(root.gui_get_focus_owner()!=prior,"D-pad moves menu focus")
	var selected := button_with("stage:sunlit_cape")
	selected.grab_focus()
	await press(JOY_BUTTON_A)
	check(app.chosen_stage=="sunlit_cape" and RallyMenuInput.token(root.gui_get_focus_owner())=="stage:sunlit_cape","Choosing a stage preserves focus across page rebuild")
	await press(JOY_BUTTON_B)
	check(app.screen=="home" and root.gui_get_focus_owner()!=null,"East button returns to title and restores focus")
	button_with("设置").grab_focus()
	await press(JOY_BUTTON_A)
	check(app.screen=="settings" and root.gui_get_focus_owner()!=null,"Settings opens with gamepad focus")
	var categories: RallySettingsPanel=app.ui.find_children("*","RallySettingsPanel",true,false)[0]
	categories.tabs[0].grab_focus()
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_A)
	check(categories.pages[1].visible,"D-pad and confirm switch settings category")
	categories.widgets.show_fps.grab_focus()
	var fps: bool=app.prefs.values.show_fps
	await press(JOY_BUTTON_A)
	check(app.prefs.values.show_fps!=fps,"Confirm toggles a setting through its actual signal")
	categories.select(2)
	var voice: OptionButton=categories.widgets.voice
	voice.grab_focus()
	await press(JOY_BUTTON_A)
	check(voice.get_popup().visible,"Confirm opens a dropdown")
	await press(JOY_BUTTON_B)
	check(not voice.get_popup().visible and app.screen=="settings","Cancel closes dropdown without leaving its page")
	await press(JOY_BUTTON_B)
	check(app.screen=="home" and RallyMenuInput.token(root.gui_get_focus_owner())=="设置","Returning restores the title settings tile")
	var axis:=InputEventJoypadMotion.new()
	axis.device=7
	axis.axis=JOY_AXIS_LEFT_X
	axis.axis_value=-.9
	Input.parse_input_event(axis)
	await process_frame
	axis=axis.duplicate();axis.axis_value=0;Input.parse_input_event(axis)
	check(RallyMenuInput.token(root.gui_get_focus_owner())=="自由练习","Left stick moves title focus")
	for page: Callable in [app.show_guide,app.show_records,app.show_credits,app.show_gallery]:
		page.call()
		await settle()
		check(root.gui_get_focus_owner()!=null,app.screen+" receives initial focus")
		await press(JOY_BUTTON_B)
		check(app.screen=="home","Secondary page returns with the east button")
	app.show_bindings()
	await settle()
	button_with("binding:"+str(KEY_W)).grab_focus()
	await press(JOY_BUTTON_A)
	check(not app.binding_wait.is_empty(),"Confirm begins keyboard remapping")
	await press(JOY_BUTTON_B)
	check(app.binding_wait.is_empty() and app.screen=="bindings","Cancel exits remapping capture without leaving the page")
	await press(JOY_BUTTON_B)
	check(app.screen=="settings","Nested page returns to settings")
	app.show_plate_setup(true)
	await settle()
	await press(JOY_BUTTON_B)
	check(app.screen=="plate","Cancel cannot bypass required first-use plate entry")
	app.show_plate_setup(false)
	await settle()
	await press(JOY_BUTTON_B)
	check(app.screen=="settings","Editing a plate can return to settings")
	app.profile.data.unlocked_power_tier=1
	app.show_vehicles()
	await settle()
	button_with("power:R200:0").grab_focus()
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(RallyMenuInput.token(root.gui_get_focus_owner())=="power:R200:1","D-pad navigates power versions within a vehicle")
	await press(JOY_BUTTON_A)
	check(app.chosen_vehicle=="R200" and app.chosen_power_tier==1 and RallyMenuInput.token(root.gui_get_focus_owner())=="power:R200:1","Power selection keeps the selected control focused")
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(not (root.gui_get_focus_owner() is BaseButton and root.gui_get_focus_owner().disabled),"Navigation skips locked power buttons")
	await press(JOY_BUTTON_B)
	check(app.screen=="stages","Vehicle page returns to stage selection")
	app.chosen_stage="sunset_ridge"
	await app.start_race()
	var scene: Node3D=app.race
	if paused: scene._toggle_pause()
	await press(JOY_BUTTON_START)
	check(paused and scene.pause_menu.visible,"Start opens the pause menu")
	await press(JOY_BUTTON_A)
	check(not paused and not scene.pause_menu.visible,"Confirm resumes driving without triggering the handbrake")
	check(not scene.controls.buttons.get(JOY_BUTTON_A,false),"Menu confirm does not leak into driving input")
	await press(JOY_BUTTON_START)
	scene.pause_menu.autopilot_selector.grab_focus()
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_B)
	check(paused and not scene.pause_menu.autopilot_selector.get_popup().visible,"Closing pause dropdown does not resume driving")
	await press(JOY_BUTTON_B)
	check(not paused and not scene.pause_menu.visible,"East button closes pause and resumes driving")
	await press(JOY_BUTTON_START)
	scene.pause_menu.actions.back_button.grab_focus()
	await press(JOY_BUTTON_A)
	for i: int in range(80):
		if app.screen=="stages" and not app.transitions.busy: break
		await process_frame
	check(app.screen=="stages" and not is_instance_valid(app.race),"Pause return button leaves the race through the GUI")
	app.free()
	await process_frame
	finish()

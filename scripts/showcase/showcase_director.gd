class_name RallyShowcaseDirector
extends Control

signal finished
signal exited
signal preparation_progress(value: float)
const MANIFEST := "res://resources/showcase/film.json"
const DURATION := 75.0
var worlds: Dictionary = {}
var shots: Array = []
var clock := 0.0
var playing := false
var ready_to_play := false
var active_shot := -1
var active_world := ""
var image := TextureRect.new()
var dissolve := TextureRect.new()
var curtain := ColorRect.new()
var titles := Label.new()
var pause_panel := PanelContainer.new()
var soundtrack := RallyShowcaseAudio.new()
var previous_image: ImageTexture
var sample: Array = []
var failed_message := ""
var telemetry_hud := RallyShowcaseHUD.new()
var performance := RallyShowcaseMetrics.new()

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for canvas: TextureRect in [image,dissolve]:
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		canvas.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		canvas.stretch_mode=TextureRect.STRETCH_SCALE
		canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(canvas)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color=Color.BLACK
	curtain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(telemetry_hud)
	add_child(curtain)
	titles.add_theme_font_override("font",RallyFonts.bold())
	titles.add_theme_font_size_override("font_size",32)
	titles.add_theme_color_override("font_shadow_color",Color(0,0,0,.7))
	titles.add_theme_constant_override("shadow_offset_x",2)
	titles.add_theme_constant_override("shadow_offset_y",2)
	titles.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(titles)
	add_child(soundtrack)
	performance.enabled=DisplayServer.get_name()!="headless"
	for argument: String in OS.get_cmdline_args():
		if argument.begins_with("--fixed-fps") or argument.begins_with("--write-movie"): performance.enabled=false
	_build_pause()
	resized.connect(_resize)
	get_viewport().size_changed.connect(_resize)
	_resize()

func prepare() -> bool:
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if manifest is not Dictionary:
		failed_message="演示素材读取失败"
		return false
	shots=manifest.shots
	# Check the complete bundle before allocating the three worlds.
	var clips := {}
	for id: String in manifest.clips:
		var path: String=manifest.clips[id]
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is not Dictionary or data.get("stage","") not in RallyContentCatalog.STAGES or data.get("vehicle","") not in ["R200","F160","A240"]:
			failed_message="演示驾驶素材不完整"
			return false
		if not RallyGhostRecording.valid(data.get("recording",{}),RallyContentCatalog.challenge(data.stage,data.vehicle).key()):
			failed_message="演示驾驶素材不完整"
			return false
		clips[id]=data
	var stage_ids: Array[String]=[]
	var first_shots: Dictionary={}
	for shot: Dictionary in shots:
		var clip: Dictionary=clips[shot.clip]
		if str(clip.stage) not in stage_ids:
			stage_ids.append(str(clip.stage))
			first_shots[clip.stage]=shot
	for index: int in range(stage_ids.size()):
		var id: String=stage_ids[index]
		var shot: Dictionary=first_shots[id]
		var world := RallyShowcaseWorld.new()
		worlds[id]=world
		await world.prepare(self,id,str(clips[shot.clip].vehicle),func(value: float,_message: String): preparation_progress.emit((index+value)/float(stage_ids.size())))
		world.viewport.size=RallyNativeResolution.pixel_size(self)
		for clip_id: String in clips:
			if clips[clip_id].stage==id: world.add_clip(clip_id,clips[clip_id])
		world.render(shot,float(shot.start),0)
		world.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
		world.deactivate()
	ready_to_play=true
	preparation_progress.emit(1)
	return true

func _resize() -> void:
	# Render the film at the window's real pixel size, not the 1280x720 UI canvas.
	var pixels := RallyNativeResolution.pixel_size(self)
	for world: RallyShowcaseWorld in worlds.values(): world.viewport.size=pixels
	titles.position=Vector2(40,40)
	pause_panel.position=(size-Vector2(300,240))*.5
	pause_panel.size=Vector2(300,240)

func restart() -> void:
	performance.reset()
	clock=0
	active_shot=-1
	active_world=""
	for world: RallyShowcaseWorld in worlds.values():
		world.deactivate()
		world.surface_fx.clear()
		world.scene.presentation.sky_life.reset_flights()
		world.scene.presentation.checkpoints.last_gate=-1
	playing=true
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	pause_panel.hide()
	soundtrack.start()
	seek(0)

func _process(dt: float) -> void:
	if not ready_to_play or not playing: return
	performance.tick(Time.get_ticks_usec(),clock)
	clock=minf(DURATION,clock+dt)
	_render(dt)
	if clock>=DURATION:
		playing=false
		soundtrack.silence()
		finished.emit()

func seek(seconds: float) -> void:
	performance.break_interval()
	clock=clampf(seconds,0,DURATION)
	_render(0)

func _render(dt: float) -> void:
	if not ready_to_play: return
	var index := shot_at(clock)
	var shot: Dictionary=shots[index]
	var world: RallyShowcaseWorld=worlds[shot.stage]
	if active_world!=str(shot.stage):
		if not active_world.is_empty():
			if DisplayServer.get_name()!="headless":
				previous_image=ImageTexture.create_from_image(worlds[active_world].viewport.get_texture().get_image())
				dissolve.texture=previous_image
			worlds[active_world].deactivate()
		active_world=shot.stage
		image.texture=world.viewport.get_texture()
		world.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	if index!=active_shot:
		world.surface_fx.clear()
		active_shot=index
	sample=world.render(shot,clock,dt)
	telemetry_hud.model=RallyShowcaseInstruments.model(world,shot,clock,sample)
	telemetry_hud.queue_redraw()
	var chapter_start := 0.0 if index<5 else (34.0 if index<9 else 60.0)
	var chapter_time := clock-chapter_start
	titles.text=world.scene.challenge.stage.title
	titles.modulate.a=smoothstep(0,.25,chapter_time)*(1-smoothstep(1.5,2.2,chapter_time))
	dissolve.modulate.a=(1-smoothstep(0,.4,chapter_time)) if chapter_start>0 and previous_image!=null else 0
	curtain.color.a=maxf(1-smoothstep(0,.35,clock),smoothstep(74.4,75,clock))
	soundtrack.sample(sample,world.scene.challenge.vehicle.vehicle_id,world.scene.challenge.stage.environment_id,shot.id,clock,not playing)

func shot_at(seconds: float) -> int:
	for i: int in range(shots.size()-1,-1,-1):
		if seconds>=float(shots[i].start): return i
	return 0

func set_playing(value: bool) -> void:
	if not ready_to_play: return
	performance.break_interval()
	playing=value
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN if playing else Input.MOUSE_MODE_VISIBLE
	pause_panel.visible=not playing
	if not playing:
		_render(0)
		pause_panel.get_child(0).get_child(1).grab_focus()
	else:
		for world: RallyShowcaseWorld in worlds.values():
			for entry: Dictionary in world.surface_fx.particles: entry.emitter.speed_scale=1 if world==worlds[active_world] else 0

func _input(event: InputEvent) -> void:
	if not ready_to_play or not visible: return
	var toggle: bool= event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE,KEY_ESCAPE]
	toggle=toggle or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START)
	if toggle:
		set_playing(not playing)
		get_viewport().set_input_as_handled()
	elif not playing and event.is_action_pressed("ui_cancel"):
		set_playing(true)
		get_viewport().set_input_as_handled()

func _build_pause() -> void:
	pause_panel.theme=RallyScreenprintStyle.theme()
	add_child(pause_panel)
	var list := VBoxContainer.new()
	pause_panel.add_child(list)
	var title := Label.new()
	title.text="演示已暂停"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	for entry: Array in [["继续播放",func(): set_playing(true),"play"],["重新播放",restart,"replay"],["返回主菜单",func(): exited.emit(),"exit"]]:
		var button := Button.new()
		button.text=entry[0]
		button.icon=load("res://assets/ui/icons/%s.svg"%entry[2])
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",24)
		button.custom_minimum_size=Vector2(280,52)
		button.pressed.connect(entry[1])
		list.add_child(button)
	pause_panel.hide()

func _exit_tree() -> void:
	soundtrack.dispose()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

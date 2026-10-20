class_name RallyPageTransition
extends CanvasLayer

const FLAG_ENTER_SECONDS := 0.34
const FLAG_HOLD_SECONDS := 0.43
const FLAG_EXIT_SECONDS := 0.30

# Render the shared title face once; the cloth shader bends ink and fabric together.
class FlagWordmark extends Control:
	func _draw() -> void:
		var font := RallyFonts.DISPLAY
		var text := "BRUSHLINE RALLY"
		var font_size := 150
		var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,Vector2((size.x-width)*.5,198),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)

# The overlay stays above both old and incoming pages and consumes input while moving.
class Wipe extends Control:
	var cloth := ShaderMaterial.new()
	var wind_time: float = 0.0
	var phase: float = 0:
		set(value):
			phase = value
			cloth.set_shader_parameter("phase",value)
			queue_redraw()
	var black: bool = false:
		set(value):
			black = value
			material = null if value else cloth
			queue_redraw()

	func _ready() -> void:
		cloth.shader = preload("res://assets/shaders/flag_cloth.gdshader")
		material = cloth
		var ink := SubViewport.new()
		ink.size = Vector2i(1536,256)
		ink.transparent_bg = true
		ink.disable_3d = true
		ink.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(ink)
		var wordmark := FlagWordmark.new()
		wordmark.size = ink.size
		ink.add_child(wordmark)
		cloth.set_shader_parameter("wordmark",ink.get_texture())
		resized.connect(_resize_cloth)
		_resize_cloth()

	func _resize_cloth() -> void:
		cloth.set_shader_parameter("viewport_size",size)

	func _process(delta: float) -> void:
		if visible and not black:
			wind_time += delta
			cloth.set_shader_parameter("wind_time",wind_time)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,phase) if black else Color.WHITE)

var wipe := Wipe.new()
var sliding: Tween
var outgoing: Control
var incoming: Control
var busy: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(wipe)
	wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wipe.visible = false

func finish_slide() -> void:
	if sliding and sliding.is_running(): sliding.kill()
	if is_instance_valid(outgoing): outgoing.queue_free()
	outgoing = null
	if is_instance_valid(incoming): incoming.position.x = 0
	incoming = null
	if not busy: wipe.visible = false

func slide(old_page: Control,new_page: Control,direction: float) -> void:
	finish_slide()
	outgoing = old_page
	incoming = new_page
	if DisplayServer.get_name()=="headless":
		finish_slide()
		return
	wipe.black = true
	wipe.phase = 0
	wipe.show()
	if reduced_motion or new_page.get_meta("comic_page",false) or old_page.get_meta("comic_page",false):
		_comic_slide.call_deferred(old_page,new_page,direction)
		return
	var width := get_viewport().get_visible_rect().size.x
	new_page.position.x = width*direction
	sliding = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sliding.tween_property(old_page,"position:x",-width*direction,.20)
	sliding.tween_property(new_page,"position:x",0.0,.20)
	sliding.chain().tween_callback(_complete_slide)

func _comic_slide(old_page: Control,new_page: Control,direction: float) -> void:
	await get_tree().process_frame
	if not is_instance_valid(new_page) or incoming!=new_page: return
	sliding=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sliding.tween_property(old_page,"modulate:a",0.0,.12)
	if reduced_motion:
		new_page.modulate.a=0
		sliding.tween_property(new_page,"modulate:a",1.0,.12)
		sliding.chain().tween_callback(_complete_slide)
		return
	var outgoing_index := 0
	for panel: Node in old_page.find_children("*","PanelContainer",true,false):
		if not panel.get_meta("comic_card",false): continue
		var content: Control=panel.get_child(0)
		sliding.tween_property(content,"position:x",content.position.x-72*direction,.14).set_delay(outgoing_index*.025)
		outgoing_index+=1
	var index := 0
	for panel: Node in new_page.find_children("*","PanelContainer",true,false):
		if not panel.get_meta("comic_card",false): continue
		var content: Control=panel.get_child(0)
		var target := content.position.x
		content.modulate.a=0
		if not reduced_motion: content.position.x+=88*direction
		sliding.tween_property(content,"position:x",target,.16).set_delay(index*.045)
		sliding.tween_property(content,"modulate:a",1.0,.14).set_delay(index*.045)
		index+=1
	if index==0 or reduced_motion:
		new_page.modulate.a=0
		sliding.tween_property(new_page,"modulate:a",1.0,.12)
	sliding.chain().tween_callback(_complete_slide)

func _complete_slide() -> void:
	if is_instance_valid(outgoing): outgoing.queue_free()
	outgoing = null
	incoming = null
	wipe.hide()

func cover(flag: bool) -> void:
	finish_slide()
	busy = true
	wipe.black = not flag
	wipe.phase = 0
	wipe.show()
	if DisplayServer.get_name()=="headless":
		wipe.phase = 1
		return
	await create_tween().tween_property(wipe,"phase",1.0,FLAG_ENTER_SECONDS if flag else .16).set_trans(Tween.TRANS_CUBIC if flag else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if flag else Tween.EASE_IN_OUT).finished

func reveal(flag: bool) -> void:
	if DisplayServer.get_name()!="headless":
		if flag:
			# Scene swap and cloth snap cue happen before this hold; wind never stops.
			await get_tree().create_timer(FLAG_HOLD_SECONDS).timeout
		await create_tween().tween_property(wipe,"phase",2.0 if flag else 0.0,FLAG_EXIT_SECONDS if flag else .18).set_trans(Tween.TRANS_CUBIC if flag else Tween.TRANS_SINE).set_ease(Tween.EASE_IN if flag else Tween.EASE_IN_OUT).finished
	wipe.hide()
	busy = false


func _input(_event: InputEvent) -> void:
	if wipe.visible: get_viewport().set_input_as_handled()

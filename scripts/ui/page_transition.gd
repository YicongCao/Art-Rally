class_name RallyPageTransition
extends CanvasLayer

# The overlay stays above both old and incoming pages and consumes input while moving.
class Wipe extends Control:
	var phase: float = 0:
		set(value):
			phase = value
			queue_redraw()
	var black: bool = false
	func _draw() -> void:
		if black:
			draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,phase))
			return
		var width := size.x+240
		var left := -width-60+(size.x+180)*phase
		var cells := 18
		var cell := width/cells
		for x: int in range(cells):
			for y: int in range(-2,ceili(size.y/cell)+3):
				var points := PackedVector2Array()
				for corner: Vector2 in [Vector2(x,y),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
					var wave := sin(corner.y*.65+phase*5+corner.x*.25)*22
					points.append(Vector2(left+corner.x*cell+wave,corner.y*cell+sin(corner.x*.55+phase*6)*14))
				var shade := .88+.10*sin(x*.5+phase*5)
				draw_colored_polygon(points,Color(shade,shade*.99,shade*.94) if (x+y)%2==0 else Color(.035,.065,.065))

var wipe := Wipe.new()
var sliding: Tween
var outgoing: Control
var incoming: Control
var busy: bool = false

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
	var width := get_viewport().get_visible_rect().size.x
	new_page.position.x = width*direction
	sliding = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sliding.tween_property(old_page,"position:x",-width*direction,.20)
	sliding.tween_property(new_page,"position:x",0.0,.20)
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
	await create_tween().tween_property(wipe,"phase",1.0,.30 if flag else .16).set_trans(Tween.TRANS_SINE).finished

func reveal(flag: bool) -> void:
	if DisplayServer.get_name()!="headless":
		await create_tween().tween_property(wipe,"phase",2.0 if flag else 0.0,.30 if flag else .18).set_trans(Tween.TRANS_SINE).finished
	wipe.hide()
	busy = false


func _input(_event: InputEvent) -> void:
	if wipe.visible: get_viewport().set_input_as_handled()

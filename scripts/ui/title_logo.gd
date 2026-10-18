class_name RallyTitleLogo
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var face := RallyFonts.DISPLAY
	var font_size := mini(158,int(size.x/6.4))
	# The next row is painted over the lower 26 px of the wordmark.
	var baseline := size.y+24
	draw_set_transform(Vector2(22,0),0,Vector2.ONE)
	draw_string(face,Vector2(0,baseline+2),"ART RALLY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(.01,.04,.05,.28))
	draw_string(face,Vector2(0,baseline),"ART RALLY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("f3e8ce"))
	var x := minf(size.x-80,face.get_string_size("ART RALLY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+20)
	for i: int in range(3):
		var start := Vector2(x+i*15,baseline-105)
		draw_colored_polygon(PackedVector2Array([start,start+Vector2(9,0),start+Vector2(-10,59),start+Vector2(-19,59)]),Color("dfad68"))

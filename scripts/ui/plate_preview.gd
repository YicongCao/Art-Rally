class_name RallyPlatePreview
extends Control

var text: String = RallyPlateText.DEFAULT_TEXT:
	set(value):
		text = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_plate(self,Rect2(Vector2.ZERO,size),text)


static func draw_plate(canvas: CanvasItem, rect: Rect2, value: String) -> void:
	var outer := StyleBoxFlat.new()
	outer.bg_color = Color("192d2b")
	outer.set_corner_radius_all(4)
	canvas.draw_style_box(outer,rect)
	var inner := rect.grow(-maxf(2,rect.size.y*.055))
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f1e9d6")
	paper.set_corner_radius_all(2)
	canvas.draw_style_box(paper,inner)
	var face := RallyPlateText.font()
	var shown := RallyPlateText.display(value)
	var point_size := maxi(10,int(rect.size.y*.51))
	while point_size>10 and face.get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x>inner.size.x-rect.size.y*.55:
		point_size-=1
	var extent := face.get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size)
	var baseline := rect.position + Vector2((rect.size.x-extent.x)/2,(rect.size.y-face.get_height(point_size))/2+face.get_ascent(point_size))
	canvas.draw_string(face,baseline,shown,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,Color("192d2b"))
	for side: float in [.075,.925]:
		canvas.draw_circle(rect.position+Vector2(rect.size.x*side,rect.size.y*.5),maxf(1,rect.size.y*.022),Color("8f978b"))

class_name RallyArtbookPanel
extends Control

var atlas: Texture2D
var panel_index: int = 0
var caption: String = ""
var detail: bool = false
var accent := Color("f05a28")
var base_height: float=230.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	base_height=custom_minimum_size.y
	resized.connect(_resize_panel)

func _resize_panel() -> void:
	# Tall panels grow with wide layouts, so the car is never cropped into a strip.
	var desired := clampf(size.x*.72,base_height,600)
	if absf(custom_minimum_size.y-desired)>.5: custom_minimum_size.y=desired
	queue_redraw()

func _draw() -> void:
	if atlas==null: return
	var source := Rect2(atlas.get_width()*panel_index/3.0,0,atlas.get_width()/3.0,atlas.get_height())
	# Crop paper margins vertically while preserving each authored panel's width.
	var ratio := size.x/maxf(1,size.y)
	if source.size.x/source.size.y<ratio:
		var h := source.size.x/ratio
		source.position.y=(source.size.y-h)*.5
		source.size.y=h
	if detail:
		source.position+=source.size*Vector2(.12,.10)
		source.size*=.65
	draw_rect(Rect2(Vector2.ZERO,size),Color("eee2c5"))
	draw_texture_rect_region(atlas,Rect2(Vector2(4,4),size-Vector2(8,8)),source)
	draw_line(Vector2(0,size.y-2),Vector2(size.x,size.y-2),accent,4)
	draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(68,0),Vector2(58,34),Vector2(0,34)]),Color("20252b"))
	draw_string(RallyFonts.DISPLAY,Vector2(12,26),"%02d"%(panel_index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("eee2c5"))
	if not caption.is_empty():
		draw_rect(Rect2(8,size.y-34,size.x-16,26),Color(.08,.10,.13,.88))
		draw_string(RallyFonts.bold(),Vector2(18,size.y-14),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-36,16,Color("eee2c5"))

class_name RallyArtbookPanel
extends Control

# Authored Blender renders carry straight alpha; the interface supplies the paper.
var texture: Texture2D
var panel_index: int = 0
var caption: String = ""
var accent := Color("f05a28")
var source_rect := Rect2()
static var frame_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if texture!=null:
		if not frame_cache.has(texture.resource_path):
			var image := texture.get_image()
			if image.is_compressed(): image.decompress()
			frame_cache[texture.resource_path]=Rect2(image.get_used_rect()).grow(8).intersection(Rect2(Vector2.ZERO,texture.get_size()))
		source_rect=frame_cache[texture.resource_path]

func _draw() -> void:
	if texture==null: return
	var center := Vector2(size.x*.5,size.y*.79)
	# Restrained vector display marks remain visible through the transparent PNG.
	draw_set_transform(center,0,Vector2(1,.17))
	var radius := minf(size.x*.43,size.y*.67)
	draw_circle(Vector2.ZERO,radius,Color(.04,.05,.07,.14))
	draw_arc(Vector2.ZERO,radius,0,TAU,72,Color("647279",.12),1,true)
	draw_set_transform(Vector2.ZERO)
	var margin := Vector2(4,12)
	var available := size-Vector2(8,30 if caption.is_empty() else 52)
	var factor := minf(available.x/maxf(1,source_rect.size.x),available.y/maxf(1,source_rect.size.y))
	var extent := source_rect.size*maxf(.01,factor)
	var position := margin+(available-extent)*.5
	# Contain the whole silhouette, including wings, masts and tree crowns.
	draw_texture_rect_region(texture,Rect2(position,extent),source_rect)
	draw_line(Vector2(0,size.y-2),Vector2(size.x,size.y-2),Color(accent,.60),2)
	draw_string(RallyFonts.DISPLAY,Vector2(4,24),"%02d"%(panel_index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("eee2c5"))
	if not caption.is_empty():
		draw_string(RallyFonts.bold(),Vector2(4,size.y-12),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-8,16,Color("eee2c5"))

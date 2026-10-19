class_name RallyScreenprintPaper
extends Control

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)

func _draw() -> void:
 # Registration bars and broad halftone belong to the page margin, never digits.
 var colors: Array[Color]=[Color("246263"),Color("d6a83c"),Color("ae4e36"),Color("493e5c")]
 for i: int in range(4):
  var p := Vector2(size.x-112+i*22,16)
  draw_colored_polygon(PackedVector2Array([p,p+Vector2(18,0),p+Vector2(13,10),p+Vector2(-5,10)]),colors[i])
 for y: int in range(10):
  for x: int in range(24):
   var alpha := .11*float(x)/24*float(y)/10
   draw_circle(Vector2(size.x-240+x*10,size.y-110+y*10),1.2,Color(.93,.88,.77,alpha))
 draw_line(Vector2(48,size.y-17),Vector2(size.x-48,size.y-17),Color(.93,.88,.77,.18),1)

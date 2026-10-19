class_name RallyComicHUDSkins
extends Control
var regions: Array[Dictionary]=[]
var ui_scale: float=1
var ui_offset:=Vector2.ZERO
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	show_behind_parent=true
	var glass:=ShaderMaterial.new()
	glass.shader=preload("res://assets/shaders/comic_hud_glass.gdshader")
	material=glass
func _draw() -> void:
	draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)
	for region: Dictionary in regions:
		draw_texture_rect(RallyComicHUDArt.sprite(region.index),region.rect,false)

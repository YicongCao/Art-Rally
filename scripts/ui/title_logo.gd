class_name RallyTitleLogo
extends Control

var crop_bottom: bool = true
var poster_ink: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://assets/shaders/title_ink.gdshader")
	material = ink

func _draw() -> void:
	var face := RallyFonts.plate()
	var font_size := mini(158,int(size.x/10.4))
	# The next row is painted over the lower 26 px of the wordmark.
	var baseline := size.y+24 if crop_bottom else size.y-20
	draw_set_transform(Vector2(-font_size*.065,0),0,Vector2.ONE)
	material.set_shader_parameter("mark_start",face.get_string_size("BRUSHLINE RA",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x-font_size*.065)
	material.set_shader_parameter("baseline",baseline)
	material.set_shader_parameter("mark_end",face.get_string_size("BRUSHLINE RALLY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x-font_size*.065)
	var mud := RandomNumberGenerator.new()
	mud.seed = 1127
	var mud_x := face.get_string_size("BRUSHLINE RA",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	for i: int in range(18):
		var point := Vector2(mud_x+mud.randf_range(12,150),baseline-mud.randf_range(85,128))
		draw_circle(point,mud.randf_range(.7,2.2),Color(.23,.17,.10,.48))
	draw_string(face,Vector2(3,baseline+4),"BRUSHLINE RALLY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(.01,.04,.05,.28))
	if poster_ink:
		draw_string(face,Vector2(0,baseline),"BRUSHLINE",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("eb562b"))
		var next := face.get_string_size("BRUSHLINE ",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(face,Vector2(next,baseline),"RALLY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("20252b"))
	else:
		draw_string(face,Vector2(0,baseline),"BRUSHLINE RALLY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("eee2c5"))
	var x := minf(size.x-80,face.get_string_size("BRUSHLINE RALLY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+20)
	for i: int in range(3):
		var start := Vector2(x+i*15,baseline-105)
		draw_colored_polygon(PackedVector2Array([start,start+Vector2(9,0),start+Vector2(-10,59),start+Vector2(-19,59)]),Color("f05a28"))

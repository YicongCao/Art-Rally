class_name RallyMenuBackdrop
extends Control

var wash := GradientTexture2D.new()
var biome: String = "autumn"
var palettes := {"autumn":[Color("f4c0a1"),Color("a2a7be"),Color("617d78"),Color("e7ac52"),Color("22483e")],"coast":[Color("e6ecdf"),Color("8ebdc6"),Color("439ba7"),Color("e3d6b0"),Color("28544d")],"highland":[Color("c8d6d8"),Color("9aaebe"),Color("647f89"),Color("a9b486"),Color("213f40")]}


func _ready() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(.04,.10,.11,.96),Color(.04,.10,.11,.82),Color(.04,.10,.11,.06)])
	gradient.offsets = PackedFloat32Array([0,.45,1])
	wash.gradient = gradient
	wash.fill_to = Vector2(1,0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var p: Array = palettes.get(biome,palettes.autumn)
	draw_rect(Rect2(Vector2.ZERO,size),p[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 152
	for layer: int in range(3):
		var points := PackedVector2Array([Vector2(0,size.y)])
		for i: int in range(18):
			points.append(Vector2(size.x*i/17,size.y*(0.29+layer*.18+rng.randf_range(-.12,.12))))
		points.append(size)
		draw_colored_polygon(points,p[layer+1])
	for i: int in range(24):
		var x := size.x*(0.47+rng.randf()*.55)
		var base := size.y*(.58+rng.randf()*.43)
		var h := rng.randf_range(.08,.33)*size.y
		for j: int in range(3):
			var y := base-h+j*h*.24
			draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x-h*(.16+j*.04),y+h*.48),Vector2(x+h*(.16+j*.04),y+h*.48)]),p[4].lightened(rng.randf()*.10))
	# Left-side ink wash provides a consistent reading field without covering the landscape.
	draw_texture_rect(wash,Rect2(Vector2.ZERO,size),false)

class_name RallyRacingPatina
extends Control

var page_corner: bool = false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	focus_mode=Control.FOCUS_NONE
	clip_contents=true
	resized.connect(queue_redraw)

static func select_mark(control: Control,selected: bool) -> void:
	var mark := control.get_node_or_null("SelectionPatina") as RallyRacingPatina
	if mark==null:
		mark=RallyRacingPatina.new()
		mark.name="SelectionPatina"
		control.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.visible=selected

func _draw() -> void:
	var scale := clampf(size.y/75,.48,1.25)
	var origin := size-Vector2(67,30)*scale
	if page_corner:
		scale=clampf(size.y/240,2,4)
		origin=size-Vector2(85,40)*scale
	var ink := Color(.19,.25,.22,.10 if page_corner else .18)
	var soil := Color(.42,.29,.15,.13 if page_corner else .22)
	_track(origin,scale,Vector2(.64,-.77),ink)
	if page_corner:
		_track(size-Vector2(84,37)*scale,scale*.86,Vector2(.80,.60),Color(.19,.25,.22,.075))
	var random := RandomNumberGenerator.new()
	random.seed=3719
	for i: int in range(36):
		var at := origin+Vector2(random.randf_range(-35,50),random.randf_range(-32,26))*scale
		var radius: float = random.randf_range(.6,2.3)*scale*(1.8 if i%8==0 else 1)
		var polygon := PackedVector2Array()
		for corner: int in range(7): polygon.append(at+Vector2.from_angle(corner*TAU/7)*radius*random.randf_range(.6,1.2))
		draw_colored_polygon(polygon,soil)


func _track(origin: Vector2,scale: float,along: Vector2,ink: Color) -> void:
	var across := along.orthogonal()
	for row: int in range(-5,7):
		for side: float in [-1,1]:
			var points := PackedVector2Array()
			for p: Vector2 in [Vector2(0,3),Vector2(6,13),Vector2(12,13),Vector2(6,3)]:
				points.append(origin+(along*(row*12+p.x)+across*p.y*side)*scale)
			draw_colored_polygon(points,ink)

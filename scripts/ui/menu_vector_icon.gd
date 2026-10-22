class_name RallyMenuVectorIcon
extends Control

# Direct CanvasItem geometry: no small imported texture to magnify on Retina.
var symbol: String = "garage"
var ink := Color("fff0d3")
const SYMBOLS := ["challenge","play","settings","garage","practice","gallery","guide","records","credits","exit"]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _line(points: Array,closed: bool=false) -> void:
	var path := PackedVector2Array()
	for point: Vector2 in points: path.append(point)
	if closed: path.append(path[0])
	draw_polyline(path,ink,3.2,true)

func _draw() -> void:
	var factor := minf(size.x,size.y)/64
	draw_set_transform((size-Vector2.ONE*64*factor)*.5,0,Vector2.ONE*factor)
	match symbol:
		"challenge":
			_line([Vector2(13,56),Vector2(13,9)])
			_line([Vector2(14,13),Vector2(26,9),Vector2(39,15),Vector2(52,11),Vector2(52,37),Vector2(39,41),Vector2(26,35),Vector2(14,39)])
			for x: float in [26,39]: _line([Vector2(x,12),Vector2(x,37)])
			_line([Vector2(14,26),Vector2(26,22),Vector2(39,28),Vector2(52,24)])
		"play":
			_line([Vector2(20,11),Vector2(52,32),Vector2(20,53)],true)
		"settings":
			var path: Array=[]
			for i: int in range(32):
				var radius := 25.0 if i%4 in [1,2] else 19.0
				path.append(Vector2(32,32)+Vector2.from_angle(i*TAU/32)*radius)
			_line(path,true)
			draw_circle(Vector2(32,32),8,ink,false,3.2,true)
		"garage":
			_line([Vector2(7,53),Vector2(7,20),Vector2(32,6),Vector2(57,20),Vector2(57,53)])
			_line([Vector2(15,53),Vector2(15,23),Vector2(49,23),Vector2(49,53)])
			for y: float in [29,35]: _line([Vector2(16,y),Vector2(48,y)])
			_line([Vector2(20,53),Vector2(20,46),Vector2(25,41),Vector2(39,41),Vector2(44,46),Vector2(44,53)],true)
			for x: float in [25,39]: draw_circle(Vector2(x,49),1.8,ink,true,-1,true)
		"practice":
			_line([Vector2(18,57),Vector2(22,43),Vector2(40,34),Vector2(42,20),Vector2(34,7)])
			_line([Vector2(35,57),Vector2(37,47),Vector2(54,38),Vector2(56,17),Vector2(47,7)])
			for at: Vector2 in [Vector2(27,51),Vector2(39,40),Vector2(49,27),Vector2(45,13)]: _line([at,at+Vector2(0,4)])
		"gallery":
			_line([Vector2(8,13),Vector2(56,13),Vector2(56,51),Vector2(8,51)],true)
			_line([Vector2(10,45),Vector2(26,28),Vector2(36,39),Vector2(43,32),Vector2(55,45)])
			draw_circle(Vector2(44,23),4,ink,false,3.2,true)
		"guide":
			_line([Vector2(32,16),Vector2(19,10),Vector2(7,12),Vector2(7,49),Vector2(19,47),Vector2(32,53),Vector2(45,47),Vector2(57,49),Vector2(57,12),Vector2(45,10)],true)
			_line([Vector2(32,16),Vector2(32,53)])
		"records":
			_line([Vector2(9,55),Vector2(9,34),Vector2(24,34),Vector2(24,22),Vector2(40,22),Vector2(40,40),Vector2(55,40),Vector2(55,55)],true)
			draw_circle(Vector2(32,11),5,ink,false,3.2,true)
		"credits":
			draw_circle(Vector2(32,17),9,ink,false,3.2,true)
			draw_arc(Vector2(32,51),18,PI,TAU,24,ink,3.2,true)
			_line([Vector2(14,51),Vector2(50,51)])
		"exit":
			_line([Vector2(30,9),Vector2(12,9),Vector2(12,55),Vector2(30,55)])
			_line([Vector2(26,32),Vector2(56,32),Vector2(45,21)])
			_line([Vector2(56,32),Vector2(45,43)])

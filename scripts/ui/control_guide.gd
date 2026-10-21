class_name RallyControlGuide
extends Control

const CONTROLLER := preload("res://assets/ui/guide/controller-wireframe.svg")
const PAPER := Color("fff0d3")
const ORANGE := Color("f2642d")
const MUTED := Color("bac7c0")
var gamepad := false
var bindings: Dictionary={}
var font := RallyFonts.regular()
var bold := RallyFonts.bold()

func _ready() -> void:
	custom_minimum_size=Vector2(0,360)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var factor := minf(size.x/560,size.y/370)
	draw_set_transform(Vector2((size.x-560*factor)*.5,8),0,Vector2.ONE*factor)
	if gamepad: _controller()
	else: _keyboard()

func _text(value: String,at: Vector2,px: int=15,color: Color=PAPER) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func _leader(points: Array,label: String,at: Vector2) -> void:
	draw_polyline(PackedVector2Array(points),Color(ORANGE,.8),1.5,true)
	draw_circle(points[0],3,ORANGE,true,-1,true)
	_text(label,at,14)

func _controller() -> void:
	draw_texture_rect(CONTROLLER,Rect2(0,12,560,330),false)
	_leader([Vector2(192,44),Vector2(130,44),Vector2(130,24)],"LT / L2  制动",Vector2(12,24))
	_leader([Vector2(369,44),Vector2(430,44),Vector2(430,24)],"RT / R2  加速",Vector2(435,24))
	_leader([Vector2(192,76),Vector2(99,76)],"LB / L1  降挡",Vector2(4,69))
	_leader([Vector2(368,76),Vector2(454,76)],"RB / R1  升挡",Vector2(445,69))
	_leader([Vector2(191,138),Vector2(88,138)],"左摇杆  转向",Vector2(0,130))
	_leader([Vector2(229,198),Vector2(98,198)],"十字键  菜单",Vector2(0,190))
	_leader([Vector2(322,195),Vector2(322,292),Vector2(388,292)],"右摇杆  环视 / 按下回正",Vector2(315,316))
	_leader([Vector2(262,129),Vector2(262,278),Vector2(169,278)],"Back / Select  重跑",Vector2(20,298))
	_leader([Vector2(298,129),Vector2(281,150),Vector2(281,317)],"Start / Options  暂停",Vector2(197,343))
	for entry: Array in [["Y",Vector2(371,119)],["X",Vector2(348,142)],["B",Vector2(394,142)],["A",Vector2(371,165)]]:
		_text(entry[0],entry[1]-Vector2(5,0),12,ORANGE)
	_leader([Vector2(382,114),Vector2(432,104)],"Y / △  恢复",Vector2(437,109))
	_leader([Vector2(405,138),Vector2(432,138)],"B / ○  返回",Vector2(437,143))
	_leader([Vector2(382,161),Vector2(432,171)],"A / ×  手刹",Vector2(437,176))
	_leader([Vector2(348,138),Vector2(332,151),Vector2(431,211)],"X / □  镜头",Vector2(437,216))
	_text("菜单：左摇杆 / 十字键导航，南侧键确认，东侧键返回。",Vector2(20,367),13,MUTED)

func _key(rect: Rect2,code: int,action: String) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color=Color(0,0,0,0)
	box.border_color=Color(PAPER,.8)
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	draw_style_box(box,rect)
	var assigned := int(bindings.get(str(code),code))
	var caption := OS.get_keycode_string(assigned)
	if code==KEY_SPACE and assigned==code: caption="SPACE"
	_text(caption,rect.position+Vector2(8,20),16,ORANGE)
	_text(action,rect.position+Vector2(8,41),13)

func _keyboard() -> void:
	# Deliberately sparse QWERTY schematic, showing only useful driving keys.
	_key(Rect2(6,10,70,50),KEY_ESCAPE,"暂停")
	_key(Rect2(164,10,70,50),KEY_F5,"重跑")
	for entry: Array in [[KEY_Q,"降挡"],[KEY_W,"加速"],[KEY_E,"升挡"],[KEY_R,"恢复"],[KEY_T,"遥测"]]:
		var index: int=[KEY_Q,KEY_W,KEY_E,KEY_R,KEY_T].find(entry[0])
		_key(Rect2(6+index*78,84,70,52),entry[0],entry[1])
	for entry: Array in [[KEY_A,"左转"],[KEY_S,"制动"],[KEY_D,"右转"]]:
		var index: int=[KEY_A,KEY_S,KEY_D].find(entry[0])
		_key(Rect2(24+index*78,144,70,52),entry[0],entry[1])
	_key(Rect2(198,204,70,52),KEY_C,"镜头")
	_key(Rect2(354,204,92,52),KEY_M,"手动 / 自动")
	_key(Rect2(86,264,238,50),KEY_SPACE,"手刹")
	for entry: Array in [[KEY_UP,"加速",Vector2(447,88)],[KEY_LEFT,"左转",Vector2(386,147)],[KEY_DOWN,"制动",Vector2(447,147)],[KEY_RIGHT,"右转",Vector2(508,147)]]:
		_key(Rect2(entry[2],Vector2(51,51)),entry[0],entry[1])
	# Mouse is used by menus, not bound to vehicle steering.
	draw_arc(Vector2(498,255),20,PI,TAU,24,PAPER,1.5,true)
	draw_arc(Vector2(498,277),20,0,PI,24,PAPER,1.5,true)
	draw_line(Vector2(478,255),Vector2(478,277),PAPER,1.5,true)
	draw_line(Vector2(518,255),Vector2(518,277),PAPER,1.5,true)
	draw_line(Vector2(498,235),Vector2(498,257),ORANGE,1.5,true)
	_text("鼠标：菜单选择",Vector2(448,319),13,MUTED)
	_text("停稳后持续制动 0.6 秒可倒车；Q / E 用于手动换挡。",Vector2(6,346),13,MUTED)
	_text("按键显示当前绑定；位置为简化示意。方向键始终可用。",Vector2(6,367),13,MUTED)

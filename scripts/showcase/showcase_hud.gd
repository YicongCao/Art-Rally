class_name RallyShowcaseHUD
extends Control

const PAPER := RallyHUD.PAPER
const ORANGE := RallyHUD.AMBER
const MUTED := Color("b5c4c0")
const CYAN := Color("85dcdf")
const GRID := Color(1,1,1,.14)
var model: Dictionary={}
var font := RallyFonts.regular()
var numbers := RallyHUD._racing_font()
var layout: Dictionary={}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if model.is_empty(): return
	layout=RallyHUD.layout_for(size)
	draw_set_transform(layout.offset,0,Vector2.ONE*layout.scale)
	_panel(Rect2(28,550,330,142))
	_panel(Rect2(872,550,380,142))
	_label("车身动态",Vector2(46,575),14,MUTED)
	_label("侧滑角",Vector2(48,602),13,PAPER)
	_label("%.1f°"%absf(model.slip),Vector2(48,641),32,ORANGE if absf(model.slip)>=10 else PAPER,numbers)
	_label("油门",Vector2(48,676),11,MUTED)
	_bar(Rect2(80,669,51,4),model.throttle,CYAN)
	_label("制动",Vector2(143,676),11,MUTED)
	_bar(Rect2(175,669,51,4),model.brake,ORANGE)
	# Fixed velocity arrow versus body heading makes oversteer readable at a glance.
	var center := Vector2(173,624)
	draw_line(center+Vector2(0,22),center-Vector2(0,30),CYAN,1.5,true)
	draw_polyline(PackedVector2Array([center+Vector2(-4,-24),center+Vector2(0,-30),center+Vector2(4,-24)]),CYAN,1.5,true)
	var angle := deg_to_rad(-model.slip)
	var car := PackedVector2Array()
	for p: Vector2 in [Vector2(-8,-17),Vector2(8,-17),Vector2(10,17),Vector2(-10,17),Vector2(-8,-17)]: car.append(center+p.rotated(angle))
	draw_polyline(car,PAPER,2,true)
	for side: int in [-1,1]:
		var at := center+Vector2(side*13,-10).rotated(angle)
		var direction := Vector2(0,5).rotated(angle+float(model.steer))
		draw_line(at-direction,at+direction,ORANGE,3,true)
	var g: Vector3=model.g
	var gc := Vector2(291,617)
	draw_arc(gc,34,0,TAU,64,GRID,1,true)
	draw_arc(gc,17,0,TAU,48,GRID,1,true)
	draw_line(gc-Vector2(34,0),gc+Vector2(34,0),GRID,1,true)
	draw_line(gc-Vector2(0,34),gc+Vector2(0,34),GRID,1,true)
	var ball := Vector2(g.x,g.z).limit_length(1)*34
	draw_line(gc,gc+ball,ORANGE,2,true)
	draw_circle(gc+ball,4,ORANGE,true,-1,true)
	_label("1 G",Vector2(276,578),11,MUTED)
	_label("横 %+.2f"%g.x,Vector2(248,669),12,PAPER)
	_label("纵 %+.2f"%-g.z,Vector2(248,685),12,PAPER)
	var drive: RallyDrivetrainConfig=model.drive
	_label("%s / %s"%[model.car,drive.drive_layout],Vector2(894,575),14,MUTED)
	_label("%03d"%roundi(model.speed),Vector2(895,637),53,PAPER,numbers)
	_label("KM/H",Vector2(898,658),12,MUTED,numbers)
	_label(str(model.gear),Vector2(1007,631),38,ORANGE,numbers)
	_label("挡",Vector2(1017,654),11,MUTED)
	draw_line(Vector2(1055,574),Vector2(1055,672),GRID,1,true)
	_label("全油门扭矩曲线",Vector2(1071,575),12,MUTED)
	var chart := Rect2(1073,591,155,49)
	var maximum := 1.0
	for rpm: float in drive.torque_rpms: maximum=maxf(maximum,drive.torque_at(rpm))
	var points := PackedVector2Array()
	for i: int in range(65):
		var rpm := lerpf(drive.idle_rpm,drive.redline_rpm,i/64.0)
		points.append(Vector2(chart.position.x+chart.size.x*i/64,chart.end.y-drive.torque_at(rpm)/maximum*chart.size.y))
	draw_line(chart.position+Vector2(0,chart.size.y),chart.end,GRID,1,true)
	draw_polyline(points,CYAN,1.8,true)
	var x := chart.position.x+chart.size.x*clampf((model.rpm-drive.idle_rpm)/(drive.redline_rpm-drive.idle_rpm),0,1)
	var y := chart.end.y-drive.torque_at(model.rpm)/maximum*chart.size.y
	draw_line(Vector2(x,chart.position.y),Vector2(x,chart.end.y),Color(ORANGE,.45),1,true)
	draw_circle(Vector2(x,y),3.5,ORANGE,true,-1,true)
	_label("%d Nm"%drive.torque_at(model.rpm),Vector2(1072,658),15,PAPER,numbers)
	_label("%d RPM"%model.rpm,Vector2(1160,658),13,MUTED,numbers)
	for i: int in range(30):
		var color := ORANGE if i<30*model.rpm/drive.redline_rpm else GRID
		draw_rect(Rect2(896+i*11,678,8,3),color)

func _panel(rect: Rect2) -> void:
	var p := rect.position
	var e := rect.end
	var points := PackedVector2Array([p+Vector2(12,0),Vector2(e.x,p.y),e-Vector2(12,0),Vector2(p.x,e.y)])
	draw_colored_polygon(points,Color(.035,.055,.065,.86))
	points.append(points[0])
	draw_polyline(points,GRID,1,true)
	draw_line(p+Vector2(12,0),p+Vector2(48,0),ORANGE,3,true)

func _bar(rect: Rect2,value: float,color: Color) -> void:
	draw_rect(rect,GRID)
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(value,0,1),rect.size.y)),color)

func _label(text: String,at: Vector2,px: int,color: Color,face: Font=null) -> void:
	draw_string(font if face==null else face,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

class_name RallyShowcaseResults
extends Control

var report: Dictionary={}
var font := RallyFonts.regular()
var numbers := RallyHUD._racing_font()
const PAPER := Color("fff0d3")
const MUTED := Color("b5c4c0")
const ORANGE := Color("f2642d")
const CYAN := Color("85dcdf")

func _ready() -> void:
	custom_minimum_size=Vector2(0,310)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var factor := minf(size.x/1040,1.0)
	draw_set_transform(Vector2((size.x-1040*factor)*.5,0),0,Vector2.ONE*factor)
	var panel := StyleBoxFlat.new()
	panel.bg_color=Color(.035,.055,.065,.94)
	panel.set_corner_radius_all(6)
	draw_style_box(panel,Rect2(0,0,1040,310))
	if report.is_empty():
		_text("尚无本次播放的帧率记录",Vector2(32,80),24,PAPER)
		_text("完整播放演示后显示实测结果。固定帧率录制不计入性能统计。",Vector2(32,117),16,MUTED)
		return
	for i: int in range(3):
		var x := 32+i*337
		_text(["平均帧率","最高帧率","最低帧率"][i],Vector2(x,33),15,MUTED)
		_text("%.1f"%report[["average","maximum","minimum"][i]],Vector2(x,80),38,ORANGE if i==0 else PAPER,numbers)
		_text("FPS",Vector2(x+145,76),14,MUTED,numbers)
	var plot := Rect2(54,112,952,135)
	var peak := 60.0
	for point: Vector2 in report.curve: peak=maxf(peak,point.y)
	peak=ceilf(peak/30)*30
	for i: int in range(4):
		var y := plot.end.y-plot.size.y*i/3
		draw_line(Vector2(plot.position.x,y),Vector2(plot.end.x,y),Color(1,1,1,.12),1,true)
		_text("%d"%(peak*i/3),Vector2(12,y+4),11,MUTED)
	for time: float in [0,34,60,75]:
		var x := plot.position.x+plot.size.x*time/75
		draw_line(Vector2(x,plot.position.y),Vector2(x,plot.end.y),Color(1,1,1,.1),1,true)
		_text("%d s"%time,Vector2(x-10,267),11,MUTED)
	var points := PackedVector2Array()
	for point: Vector2 in report.curve: points.append(Vector2(plot.position.x+plot.size.x*point.x/75,plot.end.y-plot.size.y*point.y/peak))
	if points.size()>1: draw_polyline(points,CYAN,2,true)
	_text("实播 %.1f 秒 · %d 帧    曲线：每 0.5 秒汇总；最高 / 最低：单帧瞬时值。暂停与加载不计入。"%[report.seconds,report.frames],Vector2(32,295),12,MUTED)

func _text(text: String,at: Vector2,px: int,color: Color,face: Font=null) -> void:
	draw_string(font if face==null else face,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

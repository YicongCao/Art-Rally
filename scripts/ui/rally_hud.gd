class_name RallyHUD
extends Control

const INK := Color("102823")
const PAPER := Color("eee7d4")
const AMBER := Color("e8ac59")
const MUTED := Color("9ea99c")
const RED := Color("e56b4f")
const NOTE_TEXT := {"LEFT_MEDIUM":"左弯 3", "RIGHT_MEDIUM":"右弯 3", "LEFT_TIGHT":"左急弯", "RIGHT_TIGHT":"右急弯", "MUD_NARROW":"泥地 · 收窄", "WATER":"积水 · 减速", "ASPHALT":"进入柏油", "GRAVEL":"进入砂石", "CREST_JUMP":"坡顶 · 跳跃", "FINISH":"终点"}
var title_font := SystemFont.new()
var number_font := SystemFont.new()
var text_font := SystemFont.new()
var model: Dictionary = {}
var route_map := PackedVector2Array()
var map_min := Vector2.ZERO
var map_scale: float = 1
var ui_scale: float = 1
var ui_offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_font.font_names = PackedStringArray(["Avenir Next","DejaVu Sans"])
	title_font.font_weight = 700
	number_font.font_names = PackedStringArray(["Menlo","DejaVu Sans Mono"])
	text_font.font_names = PackedStringArray(["PingFang SC","Noto Sans CJK SC"])


func set_route(route: RallyStageRoute) -> void:
	route_map.clear()
	var minimum := Vector2(INF,INF)
	var maximum := Vector2(-INF,-INF)
	for point: Vector3 in route.points:
		minimum = minimum.min(Vector2(point.x,point.z))
		maximum = maximum.max(Vector2(point.x,point.z))
	map_min = minimum
	map_scale = minf(122/maxf(maximum.x-minimum.x,1),124/maxf(maximum.y-minimum.y,1))
	for i: int in range(0,route.points.size(),8):
		var point := Vector2(route.points[i].x,route.points[i].z)
		route_map.append((point-minimum)*map_scale)


static func data_for(car: RallyVehicle, session: RallyStageSession, paused: bool) -> Dictionary:
	var warning := ""
	var gate := mini(session.next_gate,session.gates.size()-1)
	var target := session.route.position_at(session.gates[gate])
	var local := car.basis.inverse()*(target-car.position)
	if session.phase == RallyStageSession.Phase.RUNNING:
		if float(session.projection.get("s",0)) > session.gates[session.next_gate]+10: warning = "漏过 CP %02d · 返回金色气柱，或 R 恢复"%(gate+1)
		elif car.linear_velocity.dot(session.route.tangent_at(session.progress)) < -2: warning = "逆行 · 请掉头"
	return {"speed":car.linear_velocity.length()*3.6,"rpm":car.drivetrain.rpm(),"redline":car.drivetrain.config.redline_rpm,
		"gear":"R" if car.drivetrain.gear<0 else ("N" if car.drivetrain.gear==0 else str(car.drivetrain.gear)),"drive_layout":car.drivetrain.config.drive_layout,
		"automatic":car.drivetrain.automatic,"throttle":car.command.throttle,"brake":car.command.brake,"handbrake":car.command.handbrake,
		"shift_sync":car.drivetrain.auto_shift_cut,"wheelspin":car.drivetrain.wheelspin > car.drivetrain.config.max_upshift_slip and car.command.throttle > 0.2 and car.drivetrain.gear > 0,
		"time":session.total_time(),"penalty":session.penalty,"progress":session.progress,"length":session.route.length-30,
		"gates":session.next_gate,"total_gates":session.gates.size(),"note":session.current_note if session.note_remaining>0 else "",
		"note_distance":maxf(0,session.note_s-session.progress),"phase":int(session.phase),"countdown":session.countdown,
		"practice":session.practice,"paused":paused,"warning":warning,"surface":car.wheels[0].surface.surface_id,
		"position":Vector2(car.position.x,car.position.z),"heading":Vector2(-car.basis.z.x,-car.basis.z.z),
		"gate_number":gate+1,"gate_distance":car.position.distance_to(target),"gate_direction":Vector2(local.x,local.z).normalized()}


func refresh(value: Dictionary) -> void:
	model = value
	queue_redraw()


static func time_text(value: float) -> String:
	return "%02d:%06.3f" % [int(value)/60,fmod(value,60)]


static func layout_for(viewport: Vector2) -> Dictionary:
	var factor := minf(viewport.x/1280,viewport.y/720)
	return {"scale":factor,"offset":(viewport-Vector2(1280,720)*factor)*0.5}


func _draw() -> void:
	if model.is_empty(): return
	var layout := layout_for(size)
	ui_scale = layout.scale
	ui_offset = layout.offset
	draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)
	panel(Rect2(24,22,260,74))
	draw_colored_polygon(PackedVector2Array([Vector2(37,38),Vector2(51,38),Vector2(43,64),Vector2(29,64)]),AMBER)
	text("ART / RALLY",Vector2(63,52),20,PAPER,title_font)
	text("夕照松岭 / 16:00 · %s"%model.get("drive_layout","AWD"),Vector2(63,78),12,MUTED)
	var auto_label := str(model.get("label",""))
	if not auto_label.is_empty():
		panel(Rect2(300,22,150,74))
		text(auto_label,Vector2(316,49),16,AMBER,title_font)
		text("%02d km/h · %+0.2f m"%[float(model.get("target_speed",0))*3.6,float(model.get("lateral_error",0))],Vector2(316,76),11,PAPER,number_font)
	if int(model.phase)!=RallyStageSession.Phase.FINISHED:
		panel(Rect2(24,105,260,42))
		text("NEXT  CP %02d  /  %d m"%[model.gate_number,model.gate_distance],Vector2(40,132),13,AMBER,number_font)
		var forward: Vector2 = model.gate_direction
		var side := Vector2(-forward.y,forward.x)
		var at := Vector2(264,126)
		draw_colored_polygon(PackedVector2Array([at+forward*10,at-forward*6+side*5,at-forward*6-side*5]),AMBER)
	panel(Rect2(968,22,288,112))
	text("自由练习" if model.practice else "赛段计时",Vector2(989,46),12,MUTED)
	text(time_text(model.time),Vector2(988,80),30,PAPER,number_font)
	if model.penalty>0: text("+%ds"%model.penalty,Vector2(1185,46),14,AMBER,number_font)
	var best_time := float(model.get("best_time",-1))
	if best_time>=0: text("%s  %s"%[model.get("best_label","个人最佳"),time_text(best_time)],Vector2(988,103),12,MUTED,number_font)
	draw_rect(Rect2(988,119,244,3),Color("3b5148"))
	draw_rect(Rect2(988,119,244*clampf(model.progress/model.length,0,1),3),AMBER)
	_draw_note()
	_draw_map()
	if int(model.get("camera_mode",0))!=2: _draw_gauge()
	var remaining := float(model.get("reverse_remaining",0))
	if remaining>0:
		panel(Rect2(440,536,400,68))
		center_text("保持制动挂倒挡 · %.1f 秒"%remaining,Vector2(640,563),17,AMBER)
		draw_rect(Rect2(460,579,360,7),Color("40574b"))
		draw_rect(Rect2(460,579,360*clampf(remaining/3.0,0,1),7),AMBER)
	elif model.get("returning_forward",false):
		center_text("切回前进挡：正在制动至停稳",Vector2(640,578),17,AMBER)
	elif model.gear=="R" and model.get("reverse_assist",false):
		center_text("倒挡 · S/↓ 倒车 · W/↑ 前进",Vector2(640,578),17,AMBER)
	if not str(model.warning).is_empty():
		panel(Rect2(422,625,435,44),Color(0.15,0.08,0.05,0.94))
		center_text(model.warning,Vector2(640,653),15,AMBER)
	elif int(model.get("camera_mode",0))!=2:
		center_text("Esc 暂停/设置    C 视角    F9 调试    F10 自动驾驶    T 遥测",Vector2(640,697),12,PAPER)
	if model.paused:
		center_text("已暂停",Vector2(640,137),20,AMBER)
	elif model.phase == RallyStageSession.Phase.COUNTDOWN and remaining<=0:
		panel(Rect2(579,270,122,112))
		center_text(str(ceili(model.countdown)),Vector2(640,352),74,AMBER,number_font)
		center_text("踩油即可发车",Vector2(640,410),17,PAPER)
	elif model.phase == RallyStageSession.Phase.ARMED:
		center_text("出发 · 穿过起点开始计时",Vector2(640,168),20,PAPER)
	elif model.phase == RallyStageSession.Phase.FINISHED:
		panel(Rect2(400,205,480,270))
		center_text("STAGE COMPLETE",Vector2(640,248),25,AMBER,title_font)
		center_text("夕照松岭 · 完赛",Vector2(640,280),17,PAPER)
		center_text(time_text(model.time),Vector2(640,336),42,PAPER,number_font)
		center_text("行驶 %s  + 罚时 %ds  /  检查点 %d/%d"%[time_text(float(model.get("elapsed",model.time-model.penalty))),model.penalty,model.gates,model.total_gates],Vector2(640,374),14,MUTED)
		var result_line := str(model.get("best_label","个人最佳"))
		if best_time>=0: result_line += "  "+time_text(best_time)
		if model.get("new_record",false): result_line = "新纪录  ·  "+result_line
		center_text(result_line,Vector2(640,405),14,AMBER)
		if not auto_label.is_empty(): center_text(auto_label+" 参考驾驶",Vector2(640,429),12,MUTED)
		center_text("F5 / 手柄 Back 重跑    Esc 设置",Vector2(640,458),15,AMBER)


func _draw_note() -> void:
	var code := str(model.note)
	if code.is_empty(): return
	panel(Rect2(465,24,350,91))
	var at := Vector2(504,65)
	var direction := -1.0 if code.begins_with("LEFT") else 1.0
	if code.begins_with("LEFT") or code.begins_with("RIGHT"):
		var turn := at+Vector2(direction*16,-16)
		draw_polyline(PackedVector2Array([at+Vector2(0,25),at,turn]),AMBER,5,true)
		draw_colored_polygon(PackedVector2Array([turn+Vector2(direction*9,-3),turn+Vector2(-direction*4,-10),turn+Vector2(-direction*7,7)]),AMBER)
	elif code == "CREST_JUMP":
		draw_polyline(PackedVector2Array([at+Vector2(-24,14),at+Vector2(-8,-3),at+Vector2(7,-3),at+Vector2(25,14)]),AMBER,4,true)
	elif code == "WATER":
		for y: int in range(3): draw_polyline(PackedVector2Array([at+Vector2(-22,y*9-9),at+Vector2(-8,y*9-14),at+Vector2(6,y*9-9),at+Vector2(20,y*9-14)]),Color("9fc9c5"),3,true)
	else:
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-23),at+Vector2(24,20),at+Vector2(-24,20)]),AMBER)
		center_text("!",at+Vector2(0,13),27,INK,title_font)
	text(NOTE_TEXT.get(code,code),Vector2(550,62),22,PAPER)
	text("%d m"%model.note_distance,Vector2(550,93),18,AMBER,number_font)


func _draw_map() -> void:
	panel(Rect2(24,491,174,205))
	text("路线 / %02d"%model.gates,Vector2(41,517),13,PAPER)
	if route_map.size()>1:
		var points := PackedVector2Array()
		for point: Vector2 in route_map: points.append(Vector2(82,541)+point)
		draw_polyline(points,Color("74877a"),2,true)
		var completed := clampi(int((points.size()-1)*model.progress/model.length),1,points.size()-1)
		draw_polyline(points.slice(0,completed+1),AMBER,3,true)
		var position: Vector2 = Vector2(82,541)+(model.position-map_min)*map_scale
		var forward: Vector2 = model.heading.normalized()
		var side := Vector2(-forward.y,forward.x)
		draw_colored_polygon(PackedVector2Array([position+forward*7,position-forward*4+side*4,position-forward*4-side*4]),PAPER)
	text("%04d / %04d m"%[model.progress,model.length],Vector2(39,682),12,MUTED,number_font)


func _draw_gauge() -> void:
	panel(Rect2(994,432,262,264))
	var center := Vector2(1125,565)
	var rpm_ratio := clampf(float(model.rpm)/float(model.redline),0,1)
	for i: int in range(29):
		var angle := deg_to_rad(135+i*270.0/28)
		var ray := Vector2(cos(angle),sin(angle))
		var color := Color("40574b")
		if i/28.0 <= rpm_ratio: color = RED if i>24 else AMBER
		draw_line(center+ray*91,center+ray*(105 if i%4==0 else 99),color,3,true)
	center_text(model.gear,center+Vector2(0,-25),44,AMBER,number_font)
	center_text("%03d"%model.speed,center+Vector2(0,34),51,PAPER,number_font)
	center_text("KM/H",center+Vector2(0,54),11,MUTED,title_font)
	center_text("%04d RPM"%model.rpm,Vector2(1125,648),13,MUTED,number_font)
	text("AUTO" if model.automatic else "SEQ",Vector2(1191,455),11,MUTED,title_font)
	var surface: String = ["柏油","砂石","泥地","草土"][int(model.surface)]
	text(surface,Vector2(1012,455),13,PAPER)
	if model.handbrake>0.1: center_text("手刹",Vector2(1125,480),12,RED)
	elif model.get("shift_sync",false): center_text("同步降挡",Vector2(1125,480),12,AMBER)
	elif model.get("wheelspin",false): center_text("驱动轮空转",Vector2(1125,480),12,AMBER)
	draw_rect(Rect2(1020,672,93,4),Color("40574b"))
	draw_rect(Rect2(1020,672,93*model.throttle,4),Color("86bd9a"))
	draw_rect(Rect2(1134,672,93,4),Color("40574b"))
	draw_rect(Rect2(1134,672,93*model.brake,4),RED)


func panel(rect: Rect2, color: Color = Color(0.035,0.09,0.075,0.90)) -> void:
	var p := rect.position
	var e := rect.end
	var polygon := PackedVector2Array([p+Vector2(10,0),Vector2(e.x,p.y),Vector2(e.x,e.y-10),e-Vector2(10,0),Vector2(p.x,e.y),p+Vector2(0,10)])
	draw_colored_polygon(polygon,color)
	draw_line(p+Vector2(10,0),Vector2(e.x,p.y),Color(0.9,0.75,0.48,0.55),1,true)


func text(value: String, at: Vector2, font_size: int, color: Color = PAPER, font: Font = null) -> void:
	draw_string(text_font if font==null else font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)


func center_text(value: String, at: Vector2, font_size: int, color: Color = PAPER, font: Font = null) -> void:
	var selected := text_font if font==null else font
	text(value,at-Vector2(selected.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5,0),font_size,color,selected)

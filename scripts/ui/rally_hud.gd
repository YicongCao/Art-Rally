class_name RallyHUD
extends Control

const INK := Color("20252b")
const PAPER := Color("eee2c5")
const AMBER := Color("d6a83c")
const MUTED := Color("ccd5ce")
const RED := Color("c45d3f")
const GAUGE_RECT := Rect2(994,432,262,264)
const TIMER_RECT := Rect2(994,22,262,112)
const HANDBRAKE_ICON: Texture2D = preload("res://assets/ui/icons/handbrake.svg")
const SHIFT_ICON: Texture2D = preload("res://assets/ui/icons/shift.svg")
const NOTE_TEXT := {"LEFT_MEDIUM":"左弯 3", "RIGHT_MEDIUM":"右弯 3", "LEFT_TIGHT":"左急弯", "RIGHT_TIGHT":"右急弯", "LOGS":"圆木障碍 · 勿切", "ROCKFALL":"前方落石", "CAUTION_NARROW":"注意 · 收窄勿切", "CUT":"弯心平整 · 可小切", "MUD_NARROW":"泥地 · 收窄", "WATER":"积水 · 减速", "ASPHALT":"进入柏油", "GRAVEL":"进入砂石", "CREST_JUMP":"坡顶 · 跳跃", "FINISH":"终点"}
var title_font: Font = RallyFonts.bold()
var number_font: Font = RallyFonts.mono_bold()
var text_font: Font = RallyFonts.regular()
var gauge_font: Font = RallyFonts.plate()
var model: Dictionary = {}
var route_map := PackedVector2Array()
var map_min := Vector2.ZERO
var map_scale: float = 1
var ui_scale: float = 1
var ui_offset := Vector2.ZERO
var acrylic := RallyAcrylicPanels.new()
var hint_alpha: float = 1
var sector_clock: float = 99
var seen_sectors: int = 0
var sector: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(acrylic)


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
		if session.miss_notice_remaining>0: warning = "漏过检查点 · +5 s" if not session.practice else "漏过检查点"
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
		"gate_times":session.gate_times.duplicate(),"split_times":session.split_times.duplicate(),"gate_number":gate+1,"gate_distance":car.position.distance_to(target),"gate_direction":Vector2(local.x,local.z).normalized()}


func refresh(value: Dictionary) -> void:
	var times: Array = value.get("split_times",[])
	if times.size()<seen_sectors:
		sector.clear()
		sector_clock = 99
	if times.size()>seen_sectors and not times.is_empty():
		var i := times.size()-1
		sector = {"number":i+1,"seconds":float(times[i])-(float(times[i-1]) if i>0 else 0.0)}
		var best: Array = value.get("best_splits",[])
		if best.size()>i:
			sector["delta"] = sector.seconds-(float(best[i])-(float(best[i-1]) if i>0 else 0.0))
		sector_clock = 0
	seen_sectors = times.size()
	model = value
	queue_redraw()


func _process(dt: float) -> void:
	if model.is_empty() or model.get("paused",false): return
	sector_clock += dt
	hint_alpha = move_toward(hint_alpha,1.0 if float(model.get("speed",0))<.8 else 0.0,dt/.14)
	queue_redraw()


static func speed_text(value: float) -> String:
	return "%02d"%maxf(value,0)


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
	acrylic.ui_scale = ui_scale
	acrylic.ui_offset = ui_offset
	acrylic.regions.clear()
	acrylic.queue_redraw()
	draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)
	panel(Rect2(24,22,260,74))
	draw_colored_polygon(PackedVector2Array([Vector2(37,38),Vector2(51,38),Vector2(43,64),Vector2(29,64)]),AMBER)
	text("ART / RALLY",Vector2(63,52),20,PAPER,title_font)
	text("%s · %s"%[model.get("stage_title","夕照松岭"),model.get("vehicle_title",model.get("drive_layout","AWD"))],Vector2(63,78),12,MUTED)
	var auto_label := str(model.get("label",""))
	if not auto_label.is_empty():
		panel(Rect2(300,22,150,74))
		text(auto_label,Vector2(316,49),16,AMBER,title_font)
		text("%02d km/h · %+0.2f m"%[float(model.get("target_speed",0))*3.6,float(model.get("lateral_error",0))],Vector2(316,76),11,PAPER,number_font)
	if int(model.phase)!=RallyStageSession.Phase.FINISHED:
		panel(Rect2(24,105,260,42))
		draw_texture_rect(RallyGateSymbols.texture("checkpoint"),Rect2(38,115,22,22),false,AMBER)
		text("%02d  /  %d m"%[model.gate_number,model.gate_distance],Vector2(69,126-number_font.get_height(13)*.5+number_font.get_ascent(13)),13,AMBER,number_font)
		var forward: Vector2 = model.gate_direction
		var side := Vector2(-forward.y,forward.x)
		var at := Vector2(264,126)
		draw_colored_polygon(PackedVector2Array([at+forward*10,at-forward*6+side*5,at-forward*6-side*5]),AMBER)
	panel(TIMER_RECT)
	text("自由练习" if model.practice else "赛段计时",Vector2(1012,46),12,MUTED)
	center_text(time_text(model.time),Vector2(TIMER_RECT.get_center().x,83),34,PAPER,gauge_font)
	if model.penalty>0: text("+%ds"%model.penalty,Vector2(1187,46),14,AMBER,gauge_font)
	var best_time := float(model.get("best_time",-1))
	if best_time>=0: text("%s  %s"%[model.get("best_label","个人最佳"),time_text(best_time)],Vector2(1012,105),12,MUTED,gauge_font)
	draw_rect(Rect2(1012,119,226,3),Color("3b5148"))
	draw_rect(Rect2(1012,119,226*clampf(model.progress/model.length,0,1),3),AMBER)
	_draw_sector()
	if model.get("show_fps",false): text("%d FPS"%Engine.get_frames_per_second(),Vector2(1170,155),13,MUTED,number_font)
	_draw_note()
	_draw_map()
	if int(model.get("camera_mode",0))!=2: _draw_gauge()
	var remaining := float(model.get("reverse_remaining",0))
	if remaining>0:
		panel(Rect2(440,536,400,68))
		center_text("保持制动挂倒挡 · %.1f 秒"%remaining,Vector2(640,563),17,AMBER)
		draw_rect(Rect2(460,579,360,7),Color("40574b"))
		draw_rect(Rect2(460,579,360*clampf(remaining/RallyReverseAssist.HOLD_SECONDS,0,1),7),AMBER)
	elif model.get("returning_forward",false):
		center_text("切回前进挡：正在制动至停稳",Vector2(640,578),17,AMBER)
	elif model.gear=="R" and model.get("reverse_assist",false):
		center_text("倒挡 · S/↓ 倒车 · W/↑ 前进",Vector2(640,578),17,AMBER)
	if not str(model.warning).is_empty():
		panel(Rect2(422,625,435,44),Color(0.15,0.08,0.05,0.94))
		center_text(model.warning,Vector2(640,653),15,AMBER)
	elif int(model.get("camera_mode",0))!=2 and hint_alpha>0:
		center_text("Esc 设置    C 视角    T 遥测 / 调试    F10 自动驾驶",Vector2(640,697),12,Color(PAPER,hint_alpha))
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
		draw_texture_rect(RallyGateSymbols.texture("finish"),Rect2(617,213,46,46),false,AMBER)
		center_text(str(model.get("stage_title","夕照松岭"))+" · 完赛",Vector2(640,280),17,PAPER)
		center_text(time_text(model.time),Vector2(640,336),42,PAPER,number_font)
		center_text("行驶 %s  + 罚时 %ds  /  检查点 %d/%d"%[time_text(float(model.get("elapsed",model.time-model.penalty))),model.penalty,model.gates,model.total_gates],Vector2(640,374),14,MUTED)
		var result_line := str(model.get("best_label","个人最佳"))
		if best_time>=0: result_line += "  "+time_text(best_time)
		if model.get("new_record",false): result_line = "新纪录  ·  "+result_line
		center_text(result_line,Vector2(640,405),14,AMBER)
		if not auto_label.is_empty(): center_text(auto_label+" 参考驾驶",Vector2(640,429),12,MUTED)
		center_text("F5 / 手柄 Back 重跑    Esc 设置",Vector2(640,458),15,AMBER)


static func pacenote_arrow(code: String,at: Vector2 = Vector2.ZERO) -> Dictionary:
	var side := -1.0 if code.begins_with("LEFT") else 1.0
	var tight := code.ends_with("TIGHT")
	var bend := at+Vector2(0,-10) if tight else at
	var end := bend+Vector2(side*19,0) if tight else at+Vector2(side*16,-16)
	var forward := (end-bend).normalized()
	var across := Vector2(-forward.y,forward.x)
	# Derive the pointed tip and its symmetric base from the same final segment.
	# Screen Y points down: a medium right turn ends up-right, not down-right.
	var tip := end+forward*10
	var base := tip-forward*17
	return {"path":PackedVector2Array([at+Vector2(0,25),bend,end]),
		"head":PackedVector2Array([tip,base+across*8,base-across*8])}


func _draw_note() -> void:
	var code := str(model.note)
	if code.is_empty(): return
	panel(Rect2(465,24,350,91))
	var at := Vector2(504,65)
	if code.begins_with("LEFT") or code.begins_with("RIGHT"):
		var arrow := pacenote_arrow(code,at)
		draw_polyline(arrow.path,AMBER,5,true)
		draw_colored_polygon(arrow.head,AMBER)
	elif code == "FINISH":
		draw_texture_rect(RallyGateSymbols.texture("finish"),Rect2(at-Vector2(25,25),Vector2(50,50)),false)
	elif code == "CREST_JUMP":
		draw_polyline(PackedVector2Array([at+Vector2(-24,14),at+Vector2(-8,-3),at+Vector2(7,-3),at+Vector2(25,14)]),AMBER,4,true)
	elif code == "LOGS":
		for row: int in range(3):
			for col: int in range(3-row):
				var center := at+Vector2((col-(2-row)*.5)*15,12-row*13)
				draw_circle(center,6.5,AMBER,false,2,true)
				draw_circle(center,2.8,PAPER,false,1,true)
		draw_line(at+Vector2(-24,24),at+Vector2(24,-24),RED,3,true)
	elif code == "CUT":
		draw_polyline(PackedVector2Array([at+Vector2(-20,22),at+Vector2(12,-18),at+Vector2(22,-18)]),Color("9fc9c5"),4,true)
		draw_arc(at+Vector2(19,20),35,PI,PI*1.5,12,PAPER,2,true)
	elif code == "WATER":
		for y: int in range(3): draw_polyline(PackedVector2Array([at+Vector2(-22,y*9-9),at+Vector2(-8,y*9-14),at+Vector2(6,y*9-9),at+Vector2(20,y*9-14)]),Color("9fc9c5"),3,true)
	elif code == "ROCKFALL":
		draw_colored_polygon(PackedVector2Array([at+Vector2(-18,-12),at+Vector2(-4,-23),at+Vector2(15,-16),at+Vector2(22,5),at+Vector2(8,19),at+Vector2(-15,15)]),AMBER)
		draw_polyline(PackedVector2Array([at+Vector2(-25,-24),at+Vector2(-16,-15),at+Vector2(-20,-7)]),PAPER,2,true)
		draw_polyline(PackedVector2Array([at+Vector2(21,-28),at+Vector2(14,-19),at+Vector2(21,-12)]),PAPER,2,true)
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
		if model.has("ghost_position"):
			var ghost_at: Vector2 = Vector2(82,541)+(model.ghost_position-map_min)*map_scale
			draw_arc(ghost_at,5,0,TAU,16,Color("85dcdf"),2,true)
			var ghost_end := clampi(int((points.size()-1)*float(model.ghost_progress)/float(model.length)),1,points.size()-1)
			for n: int in range(0,ghost_end,3): draw_line(points[n],points[mini(n+1,ghost_end)],Color(.52,.86,.87,.7),1,true)
		var position: Vector2 = Vector2(82,541)+(model.position-map_min)*map_scale
		var forward: Vector2 = model.heading.normalized()
		var side := Vector2(-forward.y,forward.x)
		draw_colored_polygon(PackedVector2Array([position+forward*7,position-forward*4+side*4,position-forward*4-side*4]),PAPER)
	text("%04d / %04d m"%[model.progress,model.length],Vector2(39,682),12,MUTED,number_font)


func _draw_gauge() -> void:
	panel(GAUGE_RECT)
	var center := Vector2(1125,565)
	var rpm_ratio := clampf(float(model.rpm)/maxf(float(model.redline),1),0,1)
	# Patina stays on the casing; the live dial is printed above it.
	RallyGaugePatina.tread(self,Vector2(1007,527),deg_to_rad(78),9,.85)
	RallyGaugePatina.tread(self,Vector2(1200,470),deg_to_rad(33),4,.8)
	RallyGaugePatina.mud(self,Vector2(1011,652),Vector2(10,22),16)
	RallyGaugePatina.mud(self,Vector2(1239,483),Vector2(10,19),27)
	draw_circle(center,108,Color(.025,.055,.048,.16))
	draw_arc(center,108,deg_to_rad(132),deg_to_rad(408),80,Color(PAPER,.35),1,true)
	draw_arc(center,111,deg_to_rad(159),deg_to_rad(364),64,Color(PAPER,.12),1,true)
	draw_arc(center,83,deg_to_rad(135),deg_to_rad(405),72,Color(PAPER,.18),1,true)
	draw_arc(center,104,deg_to_rad(135+270*.86),deg_to_rad(405),20,Color(RED,.35),7,true)
	for i: int in range(41):
		var ray := Vector2.from_angle(deg_to_rad(135+i*270.0/40))
		var major := i%5==0
		var color := Color(RED,.9) if i>=35 else Color(PAPER,.88 if major else .42)
		draw_line(center+ray*(89 if major else 97),center+ray*103,color,2 if major else 1,true)
	# Short perimeter needle keeps the center clear, including three-digit speeds.
	var needle := Vector2.from_angle(deg_to_rad(135+rpm_ratio*270))
	var normal := needle.orthogonal()
	draw_colored_polygon(PackedVector2Array([center+needle*106,center+needle*78+normal*4,center+needle*78-normal*4]),AMBER)
	draw_arc(center,86,deg_to_rad(135),deg_to_rad(135+maxf(rpm_ratio,.001)*270),64,Color(AMBER,.55),2,true)
	# A separate gear window echoes the punched-metal gauges of rally cars.
	draw_style_box(_gear_window(),Rect2(1102,493,46,47))
	center_text(str(model.gear),Vector2(1125,532),36,AMBER,gauge_font)
	center_text(speed_text(model.speed),Vector2(1125,601),59,PAPER,gauge_font)
	center_text("KM/H",Vector2(1125,620),11,MUTED,gauge_font)
	center_text("%04d"%model.rpm,Vector2(1110,649),19,PAPER,gauge_font)
	text("RPM",Vector2(1139,648),10,AMBER,gauge_font)
	text("AUTO" if model.automatic else "SEQ",Vector2(1191,455),11,MUTED,gauge_font)
	var surface: String = ["柏油","砂石","泥地","草土"][int(model.surface)]
	text(surface,Vector2(1012,455),13,PAPER)
	var status := "handbrake" if model.handbrake>.1 else ("shift" if model.get("shift_sync",false) else "")
	if not status.is_empty(): draw_texture_rect(HANDBRAKE_ICON if status=="handbrake" else SHIFT_ICON,Rect2(1115,437,20,20),false,RED if status=="handbrake" else AMBER)
	for x: float in [1002.0,1248.0]:
		draw_circle(Vector2(x,688),2.5,Color(PAPER,.35))
		draw_line(Vector2(x-1,687),Vector2(x+1,689),Color(INK,.8),1,true)
	for i: int in range(12):
		draw_rect(Rect2(1026+i*7,674,5,4),Color("86bd9a") if i<model.throttle*12 else Color(PAPER,.16))
		draw_rect(Rect2(1141+i*7,674,5,4),RED if i<model.brake*12 else Color(PAPER,.16))


static var gear_window_style: StyleBoxFlat
static func _gear_window() -> StyleBoxFlat:
	if gear_window_style==null:
		gear_window_style = StyleBoxFlat.new()
		gear_window_style.bg_color = Color(.045,.075,.065,.48)
		gear_window_style.border_color = Color(PAPER,.45)
		gear_window_style.set_border_width_all(1)
		gear_window_style.set_corner_radius_all(3)
	return gear_window_style


func panel(rect: Rect2, color: Color = Color(0.035,0.09,0.075,0.90)) -> void:
	var p := rect.position
	var e := rect.end
	var polygon := PackedVector2Array([p+Vector2(10,0),Vector2(e.x,p.y),Vector2(e.x,e.y-10),e-Vector2(10,0),Vector2(p.x,e.y),p+Vector2(0,10)])
	var tint := color
	tint.a = (.58 if color.r > color.g else .34)*color.a/.90
	acrylic.regions.append({"shape":polygon,"tint":tint})
	var border := polygon.duplicate()
	border.append(polygon[0])
	draw_polyline(border,Color(.85,.94,.91,.19),1,true)
	draw_line(p+Vector2(10,0),Vector2(e.x,p.y),Color(.94,1.0,.97,.40),1,true)


func text(value: String, at: Vector2, font_size: int, color: Color = PAPER, font: Font = null) -> void:
	var face := text_font if font==null else font
	draw_string(face,at+Vector2(0,1.3),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0.015,.035,.03,.78*color.a))
	draw_string(face,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)


func center_text(value: String, at: Vector2, font_size: int, color: Color = PAPER, font: Font = null) -> void:
	var selected := text_font if font==null else font
	text(value,at-Vector2(selected.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5,0),font_size,color,selected)


func _draw_sector() -> void:
	if sector.is_empty() or sector_clock>3.3: return
	# Two short flashes, then a steady readable hold and a crisp 200 ms fade.
	if (sector_clock>.12 and sector_clock<.24) or (sector_clock>.36 and sector_clock<.48): return
	var opacity := 1-smoothstep(3.1,3.3,sector_clock)
	panel(Rect2(465,126,350,77 if sector.has("delta") else 54),Color(.035,.09,.075,.90*opacity))
	draw_texture_rect(preload("res://assets/ui/icons/sector.svg"),Rect2(481,141,25,25),false,Color(AMBER,opacity))
	text("%02d  %s"%[sector.number,time_text(sector.seconds)],Vector2(526,159),20,Color(PAPER,opacity),number_font)
	if sector.has("delta"):
		text("%+.2f s"%sector.delta,Vector2(526,190),19,Color(Color("91d5b2") if sector.delta<=0 else RED,opacity),number_font)

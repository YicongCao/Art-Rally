class_name RallyHUD
extends Control

const INK := Color("20252b")
const PAPER := Color("fff0d3")
const AMBER := Color("f2642d")
const MUTED := Color("ccd5ce")
const RED := Color("f04429")
const GAUGE_RECT := Rect2(994,454,262,242)
const TIMER_RECT := Rect2(994,22,262,58)
const HANDBRAKE_ICON: Texture2D = preload("res://assets/ui/icons/handbrake.svg")
const SHIFT_ICON: Texture2D = preload("res://assets/ui/icons/shift.svg")
const NOTE_TEXT := {"LEFT_MEDIUM":"左弯 3", "RIGHT_MEDIUM":"右弯 3", "LEFT_TIGHT":"左急弯", "RIGHT_TIGHT":"右急弯", "LOGS":"圆木障碍 · 勿切", "ROCKFALL":"前方落石", "CAUTION_NARROW":"注意 · 收窄勿切", "CUT":"弯心平整 · 可小切", "MUD_NARROW":"泥地 · 收窄", "WATER":"积水 · 减速", "ASPHALT":"进入柏油", "GRAVEL":"进入砂石", "CREST_JUMP":"坡顶 · 跳跃", "FINISH":"终点"}
var title_font: Font = RallyFonts.bold()
var number_font: Font = _racing_font()
var text_font: Font = RallyFonts.regular()
var gauge_font: Font = _racing_font()
static func _racing_font() -> FontVariation:
	var font := FontVariation.new()
	font.base_font=RallyFonts.DISPLAY
	font.fallbacks=[RallyFonts.bold()]
	font.variation_embolden=.65
	font.set_meta("comic_italic",true)
	font.variation_transform=Transform2D(Vector2(.88,0),Vector2(0,1),Vector2.ZERO)
	return font
var model: Dictionary = {}
var route_map := PackedVector2Array()
var map_min := Vector2.ZERO
var map_origin := Vector2(112,518)
var map_scale: float = 1
var ui_scale: float = 1
var ui_offset := Vector2.ZERO
var acrylic := RallyAcrylicPanels.new()
var skins := RallyComicHUDSkins.new()
var hint_alpha: float = 1
var sector_clock: float = 99
var seen_sectors: int = 0
var sector: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(acrylic)
	add_child(skins)


func set_route(route: RallyStageRoute) -> void:
	route_map.clear()
	var minimum := Vector2(INF,INF)
	var maximum := Vector2(-INF,-INF)
	for point: Vector3 in route.points:
		minimum = minimum.min(Vector2(point.x,point.z))
		maximum = maximum.max(Vector2(point.x,point.z))
	map_min = minimum
	map_scale = minf(86/maxf(maximum.x-minimum.x,1),124/maxf(maximum.y-minimum.y,1))
	map_origin=Vector2(112-(maximum.x-minimum.x)*map_scale*.5,518)
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
		"bend_degrees":note_bend(session),"note_distance":maxf(0,session.note_s-session.progress),"phase":int(session.phase),"countdown":session.countdown,
		"practice":session.practice,"paused":paused,"warning":warning,"surface":car.wheels[0].surface.surface_id,
		"position":Vector2(car.position.x,car.position.z),"heading":Vector2(-car.basis.z.x,-car.basis.z.z),
		"gate_times":session.gate_times.duplicate(),"split_times":session.split_times.duplicate(),"gate_number":gate+1,"gate_distance":car.position.distance_to(target),"gate_direction":Vector2(local.x,local.z).normalized()}


static func note_bend(session: RallyStageSession) -> float:
	if not (session.current_note.begins_with("LEFT") or session.current_note.begins_with("RIGHT")):return 0
	# Measure the contiguous bend, not merely the short window used to trigger
	# a spoken note. Stop at opposite curvature so S bends never cancel out.
	var sign_value := 1.0 if session.current_note.begins_with("LEFT") else -1.0
	var total := 0.0
	for direction: float in [-1,1]:
		var flat := 0
		for offset: int in range(0,96,4):
			var s := session.note_s+direction*(offset+2)
			var a := session.route.tangent_at(clampf(s-2,0,session.route.length))
			var b := session.route.tangent_at(clampf(s+2,0,session.route.length))
			var angle := a.signed_angle_to(b,Vector3.UP)*sign_value
			if angle<-.002:break
			flat=flat+1 if angle<.001 else 0
			if flat>=3:break
			total+=maxf(angle,0)
	return clampf(rad_to_deg(total),20,180)


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
	skins.ui_scale=ui_scale
	skins.ui_offset=ui_offset
	skins.regions.clear()
	skins.queue_redraw()
	draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)
	_skin(1,Rect2(24,22,270,60))
	text("BRUSHLINE RALLY",Vector2(65,65),23,PAPER,gauge_font)
	var auto_label := str(model.get("label",""))
	if not auto_label.is_empty(): text("AUTO",Vector2(311,59),13,AMBER,gauge_font)
	_skin(2,TIMER_RECT)
	center_text(time_text(model.time),Vector2(1135,64),32,PAPER,gauge_font)
	if model.penalty>0: text("+%ds"%model.penalty,Vector2(1204,99),15,AMBER,gauge_font)
	var best_time := float(model.get("best_time",-1))
	_draw_sector()
	if model.get("show_fps",false): text("%d FPS"%Engine.get_frames_per_second(),Vector2(1180,124),13,MUTED,number_font)
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
	panel(Rect2(515,24,250,91))
	var at := Vector2(560,66)
	if code.begins_with("LEFT") or code.begins_with("RIGHT"):
		var turn := RallyComicHUDArt.turn(code,float(model.get("bend_degrees",-1)))
		var texture := RallyComicHUDArt.sprite(turn.sprite)
		var arrow_size := texture.get_size()
		arrow_size*=minf(70/arrow_size.x,72/arrow_size.y)
		var rectangle := Rect2(Vector2(560,66)-arrow_size*.5,arrow_size)
		if turn.right: rectangle=Rect2(rectangle.position,Vector2(-rectangle.size.x,rectangle.size.y))
		draw_texture_rect(texture,rectangle,false)
	else:
		if code == "FINISH":
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
		var short_labels := {"LOGS":"勿切","ROCKFALL":"落石","CAUTION_NARROW":"收窄","CUT":"可切","MUD_NARROW":"泥地","WATER":"积水","ASPHALT":"柏油","GRAVEL":"砂石","CREST_JUMP":"飞坡","FINISH":"终点"}
		center_text(short_labels.get(code,"注意"),Vector2(665,54),15,PAPER)
	center_text("%d m"%model.note_distance,Vector2(665,88),24,PAPER,gauge_font)


func _draw_map() -> void:
	_skin(3,Rect2(24,491,174,205))
	if route_map.size()>1:
		var points := PackedVector2Array()
		for point: Vector2 in route_map: points.append(map_origin+point)
		draw_polyline(points,Color(PAPER,.90),3,true)
		var completed := clampi(int((points.size()-1)*model.progress/model.length),1,points.size()-1)
		draw_polyline(points.slice(0,completed+1),AMBER,3,true)
		if model.has("ghost_position"):
			var ghost_at: Vector2 = map_origin+(model.ghost_position-map_min)*map_scale
			draw_arc(ghost_at,5,0,TAU,16,Color("85dcdf"),2,true)
			var ghost_end := clampi(int((points.size()-1)*float(model.ghost_progress)/float(model.length)),1,points.size()-1)
			for n: int in range(0,ghost_end,3): draw_line(points[n],points[mini(n+1,ghost_end)],Color(.52,.86,.87,.7),1,true)
		var position: Vector2 = map_origin+(model.position-map_min)*map_scale
		var forward: Vector2 = model.heading.normalized()
		var side := Vector2(-forward.y,forward.x)
		draw_colored_polygon(PackedVector2Array([position+forward*7,position-forward*4+side*4,position-forward*4-side*4]),PAPER)
	draw_line(Vector2(41,665),Vector2(37,681),AMBER,4,true)
	# Match the rising baseline and rightward shear of the map caption plate.
	var canvas := Transform2D(Vector2(ui_scale,0),Vector2(0,ui_scale),ui_offset)
	draw_set_transform_matrix(canvas*Transform2D(Vector2(1,-.075),Vector2(-.22,1),Vector2(50,674)))
	var caption := "%02d / %d m"%[model.get("gate_number",1),model.get("gate_distance",0)]
	draw_string(gauge_font,Vector2(0,1.3),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(.015,.025,.03,.8))
	draw_string(gauge_font,Vector2.ZERO,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,PAPER)
	draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)


func _draw_gauge() -> void:
	_skin(0,GAUGE_RECT)
	var center := Vector2(1141,584)
	var rpm_ratio := clampf(float(model.rpm)/maxf(float(model.redline),1),0,1)
	var needle := Vector2.from_angle(deg_to_rad(140+rpm_ratio*260))
	var normal := needle.orthogonal()
	draw_colored_polygon(PackedVector2Array([center+needle*102,center+needle*82+normal*3,center+needle*82-normal*3]),AMBER)
	center_text(str(model.gear),Vector2(1140,548),30,AMBER,gauge_font)
	center_text(speed_text(model.speed),Vector2(1140,625),65,PAPER,gauge_font)
	center_text("KM/H",Vector2(1138,646),14,PAPER,gauge_font)
	var status := "handbrake" if model.handbrake>.1 else ("shift" if model.get("shift_sync",false) else "")
	if not status.is_empty(): draw_texture_rect(HANDBRAKE_ICON if status=="handbrake" else SHIFT_ICON,Rect2(1215,641,20,20),false,RED if status=="handbrake" else AMBER)
	for i: int in range(16):
		var x := 1074+i*8.0
		var color := AMBER if i<model.throttle*16 else Color(PAPER,.28)
		if model.brake>.1: color=RED if i<model.brake*16 else Color(PAPER,.28)
		draw_colored_polygon(PackedVector2Array([Vector2(x+2,674),Vector2(x+8,674),Vector2(x+6,680),Vector2(x,680)]),color)


func _skin(index: int,rect: Rect2) -> void:
	# Generated casing artwork masks neutral black, blurred scene transmission.
	skins.regions.append({"index":index,"rect":rect})


func panel(rect: Rect2, color: Color = Color(0.035,0.09,0.075,0.90)) -> void:
	var p := rect.position
	var e := rect.end
	var polygon := PackedVector2Array([p+Vector2(14,0),Vector2(e.x,p.y),e-Vector2(14,0),Vector2(p.x,e.y)])
	var tint := Color(.016,.018,.022,.84)
	if color.r > color.g: tint = Color(color,.82)
	var opacity := clampf(color.a/.90,0,1)
	tint.a *= opacity
	acrylic.regions.append({"shape":polygon,"tint":tint})
	var border := polygon.duplicate()
	border.append(polygon[0])
	draw_polyline(border,Color(.9,.86,.77,.16*opacity),1,true)
	draw_line(p+Vector2(14,0),p+Vector2(minf(50,rect.size.x*.20),0),Color(AMBER,opacity),3,true)


func text(value: String, at: Vector2, font_size: int, color: Color = PAPER, font: Font = null) -> void:
	var face := text_font if font==null else font
	var baseline := at
	if face.has_meta("comic_italic"):
		# Shear the canvas in screen coordinates: tops move right, baseline stays
		# level. FontVariation shear also distorts advances on some font backends.
		var canvas := Transform2D(Vector2(ui_scale,0),Vector2(0,ui_scale),ui_offset)
		draw_set_transform_matrix(canvas*Transform2D(Vector2(1,0),Vector2(-.22,1),at))
		baseline=Vector2.ZERO
	draw_string(face,baseline+Vector2(0,1.3),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0.015,.025,.03,.78*color.a))
	draw_string(face,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
	if face.has_meta("comic_italic"):draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)


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

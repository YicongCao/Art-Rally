class_name RallyCockpitDisplay
extends Control

var rpm: float = 0
var redline: float = 7600
var speed: float = 0
var gear: String = "N"
var brake: float = 0
var throttle: float = 0
var automatic: bool = true
var drive_layout: String = "AWD"
var drive_status: String = ""
var font: Font = RallyFonts.plate()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func refresh(car: RallyVehicle) -> void:
	rpm = car.drivetrain.rpm()
	redline = car.drivetrain.config.redline_rpm
	speed = car.linear_velocity.length()*3.6
	gear = "R" if car.drivetrain.gear<0 else ("N" if car.drivetrain.gear==0 else str(car.drivetrain.gear))
	brake = car.command.brake
	throttle = car.command.throttle
	automatic = car.drivetrain.automatic
	drive_layout = car.drivetrain.config.drive_layout
	drive_status = "SYNC DOWN" if car.drivetrain.auto_shift_cut else ""
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b1314"))
	RallyGaugePatina.tread(self,Vector2(10,112),deg_to_rad(72),11,1.2)
	RallyGaugePatina.tread(self,Vector2(680,108),deg_to_rad(65),10,1.2)
	RallyGaugePatina.mud(self,Vector2(744,184),Vector2(12,70),44)
	RallyGaugePatina.mud(self,Vector2(20,275),Vector2(14,12),16)
	var amber := Color("ffc36e")
	var white := Color("eee7d4")
	draw_rect(Rect2(18,18,732,5),amber)
	text("BRUSHLINE RALLY / "+drive_layout,Vector2(24,55),24,white)
	text("AUTO" if automatic else "SEQ",Vector2(626,55),23,amber)
	for i: int in range(24):
		var color := Color("26372f")
		if i/24.0<rpm/redline: color = Color("f56b4b") if i>19 else (amber if i>14 else Color("86e2b0"))
		draw_rect(Rect2(24+i*30,73,23,22),color)
	draw_rect(Rect2(24,114,122,144),Color("24342c"))
	text(gear,Vector2(55,226),98,amber)
	var speed_text := RallyHUD.speed_text(speed)
	text(speed_text,Vector2(310-font.get_string_size(speed_text,HORIZONTAL_ALIGNMENT_LEFT,-1,100).x*.5,218),100,white)
	text("KM/H",Vector2(400,252),23,white)
	text("%04d"%rpm,Vector2(533,170),46,amber)
	text("RPM",Vector2(620,203),23,white)
	text(drive_status,Vector2(185,278),17,amber)
	text("THR",Vector2(522,248),17,white)
	draw_rect(Rect2(571,234,150,10),Color("29352e"))
	draw_rect(Rect2(571,234,150*throttle,10),Color("8cd6ac"))
	text("BRK",Vector2(522,275),17,white)
	draw_rect(Rect2(571,261,150,10),Color("29352e"))
	draw_rect(Rect2(571,261,150*brake,10),Color("ec7453"))


func text(value: String,at: Vector2,font_size: int,color: Color) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

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
var font: Font = RallyFonts.mono_bold()


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
	drive_status = "SYNC DOWN" if car.drivetrain.auto_shift_cut else ("WHEELSPIN" if car.drivetrain.wheelspin > car.drivetrain.config.max_upshift_slip and throttle > 0.2 and car.drivetrain.gear > 0 else "")
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b1314"))
	for x: int in range(-300,800,18): draw_line(Vector2(x,0),Vector2(x+300,300),Color("152123"),2)
	var amber := Color("ffc36e")
	var white := Color("e7f1e6")
	draw_rect(Rect2(18,18,732,5),amber)
	text("ART RALLY / "+drive_layout,Vector2(24,55),24,white)
	text("AUTO" if automatic else "SEQ",Vector2(626,55),23,amber)
	for i: int in range(24):
		var color := Color("26372f")
		if i/24.0<rpm/redline: color = Color("f56b4b") if i>19 else (amber if i>14 else Color("86e2b0"))
		draw_rect(Rect2(24+i*30,73,23,22),color)
	draw_rect(Rect2(24,114,122,144),Color("24342c"))
	text(gear,Vector2(55,226),98,amber)
	text("%03d"%speed,Vector2(190,218),100,white)
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

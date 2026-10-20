class_name RallyBenchmarkDemo
extends Node

signal finished(report: Dictionary)
const DURATION := 120.0
var scene: Node3D
var elapsed: float = 0
var frames: Array[float]=[]
var physics: Array[float]=[]
var peak_sideslip: float=0
var recovered: bool=false
var countersteered: bool=false
var original_command: Callable
var overlay := Telemetry.new()
var samples: Array[Dictionary]=[]
var sample_clock: float=0

class Telemetry extends Control:
	var demo: RallyBenchmarkDemo
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if demo==null or not is_instance_valid(demo.scene): return
		var car: RallyVehicle=demo.scene.vehicle
		var font := RallyFonts.bold()
		var chapter := mini(2,int(demo.elapsed/40))
		draw_rect(Rect2(24,118,350,304),Color(.035,.045,.065,.88))
		draw_string(font,Vector2(40,146),["01 / 载荷与抓地","02 / 侧滑与救车","03 / 电视直播"][chapter],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f3e7cd"))
		for i: int in range(4):
			var wheel: RallyWheelState=car.wheels[i]
			var p := Vector2(42+(i%2)*156,169+(i/2)*86)
			draw_string(font,p,["FL","FR","RL","RR"][i]+"  %d N"%wheel.load,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("eee2c5"))
			draw_rect(Rect2(p+Vector2(0,8),Vector2(136,6)),Color("38414d"))
			draw_rect(Rect2(p+Vector2(0,8),Vector2(136*clampf(absf(wheel.slip_angle)/.35,0,1),6)),Color("ef652f"))
			draw_string(font,p+Vector2(0,30),"κ %.2f  α %.1f°"%[wheel.slip,rad_to_deg(wheel.slip_angle)],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a9d4d0"))
			var limit := RallyTireModel.capacity(wheel.load,car.tire)*wheel.surface.grip(wheel.longitudinal_speed)
			var usage := Vector2(wheel.longitudinal_force,wheel.lateral_force).length()/maxf(1,limit)
			draw_string(font,p+Vector2(0,52),"抓地 %d%%"%int(usage*100),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f3bf63") if usage>.8 else Color("a9d4d0"))
		draw_string(font,Vector2(40,354),"%d RPM   %d KM/H   %s"%[car.drivetrain.rpm(),car.linear_velocity.length()*3.6,"反打" if demo.countersteered else "实时模拟"],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("eee2c5"))
		draw_string(font,Vector2(40,377),"油门 %.0f%% · 制动 %.0f%% · %+.2f"%[car.command.throttle*100,car.command.brake*100,car.command.steer],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("efae6d"))

		var force := 0.0
		for wheel: RallyWheelState in car.wheels: force+=wheel.longitudinal_force
		draw_string(font,Vector2(40,403),"挡位 %d  /  纵向力 %d N"%[car.drivetrain.gear,force],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("eee2c5"))

func begin(race: Node3D) -> void:
	name="BenchmarkDemo"
	scene=race
	scene.demonstration=true
	scene._apply_preferences()
	scene.controls.allow_mechanical_shortcuts=false
	scene.camera_mode=0
	scene.ghost.hide()
	scene.session.practice=true
	scene._set_autopilot_mode_name("vgamepad")
	scene.broadcast.photos_enabled=false
	scene.wildlife.events.clear()
	scene.presentation.sky_life.clock=0
	original_command=scene.vehicle.command_source
	scene.vehicle.command_source=_command
	var layer := CanvasLayer.new()
	layer.layer=25
	add_child(layer)
	overlay.demo=self
	layer.add_child(overlay)

func _command(speed: float,dt: float) -> DriverCommand:
	var input: DriverCommand=original_command.call(speed,dt)
	# Physical input only: a short rear brake pulse initiates yaw, followed by
	# measured slip feedback. Never write vehicle transforms or fake telemetry.
	if elapsed>44 and elapsed<44.45 and speed>7:
		input.handbrake=.65
		input.throttle=.12
		input.steer=clampf(input.steer+.42,-.8,.8)
	elif elapsed>=44.45 and elapsed<52:
		var velocity: Vector3=scene.vehicle.global_basis.inverse()*scene.vehicle.linear_velocity
		var beta := atan2(velocity.x,maxf(.5,-velocity.z))
		input.handbrake=0
		input.throttle=minf(input.throttle,.30)
		input.steer=clampf(input.steer*.55+beta/scene.vehicle.config.max_steer_radians*.8,-1,1)
		countersteered=countersteered or absf(beta)>.07
	return input

func _process(dt: float) -> void:
	if scene==null or not is_instance_valid(scene.vehicle) or scene.get_tree().paused: return
	elapsed+=dt
	scene.camera_mode=0
	scene.ghost.hide()
	if elapsed>3:
		frames.append(dt*1000)
		physics.append(scene.vehicle.physics_usec/1000.0)
	var local: Vector3=scene.vehicle.global_basis.inverse()*scene.vehicle.linear_velocity
	var slip := absf(rad_to_deg(atan2(local.x,maxf(.5,-local.z))))
	if elapsed>44 and elapsed<53: peak_sideslip=maxf(peak_sideslip,slip)
	if elapsed>53 and peak_sideslip>8 and slip<4: recovered=true
	sample_clock+=dt
	if sample_clock>=.1:
		sample_clock=0
		samples.append({"t":elapsed,"s":scene.session.progress,"speed":local.length(),"sideslip_deg":slip,"steer":scene.vehicle.command.steer,"throttle":scene.vehicle.command.throttle,"brake":scene.vehicle.command.brake,"gear":scene.vehicle.drivetrain.gear,"rpm":scene.vehicle.drivetrain.rpm(),"rear_load":scene.vehicle.wheels[2].load+scene.vehicle.wheels[3].load,"wheels":wheel_snapshot()})
	if elapsed>=40:
		var car: RallyVehicle=scene.vehicle
		var target := car.global_position+Vector3.UP*.3
		var offset: Vector3 = car.global_basis*Vector3(-3.4,.65,1.7) if elapsed<80 else scene.generator.route.pose_at(scene.session.progress).basis*Vector3(-13,6,10)
		scene.camera.global_position=target+offset
		scene.camera.look_at(target)
		scene.camera.fov=52 if elapsed<80 else 42
	overlay.queue_redraw()
	if elapsed>=DURATION:
		set_process(false)
		scene.vehicle.command_source=original_command
		finished.emit(report())

func restart() -> void:
	elapsed=0
	frames.clear()
	physics.clear()
	samples.clear()
	peak_sideslip=0
	recovered=false
	countersteered=false
	sample_clock=0
	scene.vehicle.command_source=_command
	set_process(true)

func wheel_snapshot() -> Array:
	var result: Array=[]
	for wheel: RallyWheelState in scene.vehicle.wheels:
		var limit := RallyTireModel.capacity(wheel.load,scene.vehicle.tire)*wheel.surface.grip(wheel.longitudinal_speed)
		result.append({"load_n":wheel.load,"slip":wheel.slip,"angle":wheel.slip_angle,"longitudinal_n":wheel.longitudinal_force,"lateral_n":wheel.lateral_force,"capacity_n":limit})
	return result

func report() -> Dictionary:
	var sorted := frames.duplicate()
	sorted.sort()
	var physics_sorted := physics.duplicate()
	physics_sorted.sort()
	var total := 0.0
	for value: float in frames: total+=value
	return {"kind":"fixed_demo_not_full_stage","duration":elapsed,"stage":"sunset_ridge","vehicle":"R200","tier":0,"seed":scene.generator.definition.seed_value,"os":OS.get_name(),"cpu":OS.get_processor_name(),"resolution":str(scene.get_viewport().get_visible_rect().size),"renderer":RenderingServer.get_current_rendering_method(),"frames":frames.size(),"average_fps":1000*frames.size()/maxf(1,total),"p95_ms":percentile(sorted,.95),"p99_ms":percentile(sorted,.99),"physics_p95_ms":percentile(physics_sorted,.95),"physics_p99_ms":percentile(physics_sorted,.99),"physics_mean_ms":mean(physics),"peak_sideslip_deg":peak_sideslip,"countersteered":countersteered,"recovered":recovered,"resets":scene.session.reset_count,"samples":samples}

static func percentile(values: Array[float],fraction: float) -> float:
	return values[mini(values.size()-1,int(values.size()*fraction))] if not values.is_empty() else 0.0

static func mean(values: Array[float]) -> float:
	var total := 0.0
	for value: float in values: total+=value
	return total/maxi(1,values.size())

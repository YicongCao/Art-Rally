class_name RallyDriverAids
extends RefCounted

# Controllers command brake torque / engine demand only. No synthetic body forces.
var abs_enabled := true
var longitudinal_stiffness: float = 12.0
var esp_mode: int = 1 # 0 off, 1 sport, 2 full
var pressure := PackedFloat64Array([1,1,1,1])
var abs_active := false
var esp_active := false
var yaw_target: float = 0
var yaw_error: float = 0
var beta: float = 0
var engine_scale: float = 1
var esp_brakes := PackedFloat64Array([0,0,0,0])
var requested_brakes := PackedFloat64Array([0,0,0,0])
var applied_brakes := PackedFloat64Array([0,0,0,0])

func reset() -> void:
	pressure.fill(1);esp_brakes.fill(0);requested_brakes.fill(0);applied_brakes.fill(0)
	abs_active=false;esp_active=false;engine_scale=1;beta=0;yaw_target=0;yaw_error=0

func begin_tick(car: RallyVehicle,state: PhysicsDirectBodyState3D) -> void:
	abs_active=false
	longitudinal_stiffness=car.tire.longitudinal_stiffness
	var local := state.transform.basis.inverse()*state.linear_velocity
	var speed := maxf(0,-local.z)
	beta=atan2(local.x,maxf(speed,2))
	var grip := 0.0
	var support := 0
	for wheel: RallyWheelState in car.wheels:
		if wheel.grounded and wheel.load>100:
			grip+=wheel.surface.grip(speed)*car.tire.friction
			support+=1
	grip/=maxi(support,1)
	var yaw: float=state.angular_velocity.dot(state.transform.basis.y)
	yaw_target=clampf(speed/car.config.wheelbase*tan(-car.command.steer*car.config.max_steer_radians),-grip*9.81/maxf(speed,3),grip*9.81/maxf(speed,3))
	yaw_error=yaw_target-yaw
	var demand := 0.0
	if esp_mode>0 and support>=3 and speed>5 and state.transform.basis.y.y>.6 and car.command.handbrake<.05:
		var slip_limit := deg_to_rad(14 if esp_mode==1 else 8)
		var deadband := .18 if esp_mode==1 else .09
		if absf(beta)>slip_limit:
			demand=yaw_error-signf(beta)*(absf(beta)-slip_limit)*2
		elif absf(yaw_error)>deadband:
			demand=signf(yaw_error)*(absf(yaw_error)-deadband)
	var active_index := -1
	if absf(demand)>.02:
		# Understeer: inside rear helps turn-in. Oversteer/countersteer: outside
		# front opposes excess yaw. Wheel ordering is FL, FR, RL, RR.
		var understeer := demand*yaw_target>0 and absf(yaw)<absf(yaw_target) and absf(beta)<deg_to_rad(14)
		active_index=(2 if demand>0 else 3) if understeer else (0 if demand>0 else 1)
	for i: int in range(4):
		var wheel := car.wheels[i]
		var limit := RallyTireModel.capacity(wheel.load,car.tire)*wheel.surface.grip(speed)*wheel.effective_radius
		var target := minf(absf(demand)*car.config.body_mass*.9,limit*(.28 if esp_mode==1 else .45)) if i==active_index else 0.0
		esp_brakes[i]=move_toward(esp_brakes[i],target,state.step*2200)
		if esp_mode==0 or car.command.handbrake>.05 or support<3: esp_brakes[i]=0
	esp_active=esp_brakes[0]+esp_brakes[1]+esp_brakes[2]+esp_brakes[3]>15
	engine_scale=move_toward(engine_scale,.65 if esp_active else 1.0,state.step*(3 if esp_active else 1.5))
	if esp_mode==0: engine_scale=1

func brake(index: int,wheel: RallyWheelState,requested: float,dt: float) -> float:
	requested_brakes[index]=requested
	var speed := absf(wheel.longitudinal_speed)
	if not abs_enabled or not wheel.grounded or speed<2 or requested<1:
		pressure[index]=1
	else:
		var slip := (speed-absf(wheel.omega*wheel.effective_radius))/maxf(speed,3)
		# Targets follow each surface's slip-curve peak, with a useful loose-road margin.
		var target := clampf(.95/maxf(.01,longitudinal_stiffness*wheel.surface.longitudinal_scale),.075,.20)
		if slip>target+.015:
			pressure[index]=maxf(.03,pressure[index]-dt*(8+30*(slip-target)))
		elif slip<target-.015:
			pressure[index]=minf(1,pressure[index]+dt*3.5)
		abs_active=abs_active or pressure[index]<.96
	applied_brakes[index]=requested*lerpf(1,pressure[index],smoothstep(2,4,speed))
	return applied_brakes[index]

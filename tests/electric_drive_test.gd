extends "res://tests/test_suite.gd"
func _run() -> void:
 var drive:=RallyDrivetrain.new()
 drive.config=RallyContentCatalog.vehicle("P7").drivetrain_config()
 drive.tc_mode=0
 drive.reset()
 var command:=DriverCommand.new()
 var wheels: Array[RallyWheelState]=[]
 for i: int in range(4): wheels.append(RallyWheelState.new())
 command.throttle=1
 var force:=drive.step(command,wheels,1.0/120)
 var sum:=0.0
 for t: float in force: sum+=t
 check(absf(sum-drive.output_torque*drive.ratio())<.001,"EV axle split conserves input torque")
 check(force[2]>force[0],"P7 rear-biased AWD split")
 check(drive.rpm()==0 and sum>6000,"Motor delivers launch torque at zero shaft RPM")
 for wheel: RallyWheelState in wheels: wheel.omega=60
 command.throttle=0
 force=drive.step(command,wheels,1.0/120)
 check(force[0]<0 and force[2]<0,"Regeneration opposes forward rotation")
 for wheel: RallyWheelState in wheels: wheel.omega=-60
 force=drive.step(command,wheels,1.0/120)
 check(force[0]>0 and force[2]>0,"Regeneration opposes reverse rotation")
 drive.gear=0
 force=drive.step(command,wheels,1.0/120)
 check(is_zero_approx(force[0]+force[1]+force[2]+force[3]),"Neutral disconnects motor and regen")
 drive.gear=-1
 command.throttle=1
 force=drive.step(command,wheels,1.0/120)
 check(force[0]<0 and force[2]<0,"Reverse motor torque drives backwards")
 drive.gear=1
 check(not drive.request_shift(2,0),"Single-speed transmission rejects second gear")
 check(drive.request_shift(0,0),"Neutral selectable while stopped")
 drive.step(command,wheels,1.0/120)
 check(drive.request_shift(-1,0),"Reverse selectable after neutral")
 var drive5:=RallyContentCatalog.vehicle("I20").drivetrain_config()
 check(drive5.ratios.size()==5,"Rally2 has five authored ratios")
 finish()

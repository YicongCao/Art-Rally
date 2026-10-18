extends "res://tests/test_suite.gd"

func _run() -> void:
	var half := Vector3(1,.3,2)
	var center := Vector3.ZERO
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	var opening := 3.8
	check(RallyStageSession._body_crosses(Vector3(4.79,.5,3),Vector3(4.79,.5,1.9),Basis.IDENTITY,Basis.IDENTITY,half,center,forward,right,opening),"A 1cm body overlap at the outer inflatable edge is credited")
	check(not RallyStageSession._body_crosses(Vector3(4.81,.5,3),Vector3(4.81,.5,1.9),Basis.IDENTITY,Basis.IDENTITY,half,center,forward,right,opening),"A body entirely outside the inflatable is rejected")
	check(not RallyStageSession._body_crosses(Vector3(0,5,3),Vector3(0,5,1.9),Basis.IDENTITY,Basis.IDENTITY,half,center,forward,right,opening),"A car flying high over the checkpoint is rejected")
	check(not RallyStageSession._body_crosses(Vector3(0,.5,-1.9),Vector3(0,.5,-3),Basis.IDENTITY,Basis.IDENTITY,half,center,Vector3.BACK,right,opening),"Reverse travel cannot credit a gate")
	check(not RallyStageSession._body_crosses(Vector3(0,.5,4),Vector3(0,.5,3),Basis.IDENTITY,Basis.IDENTITY,half,center,forward,right,opening),"Proximity without body-plane overlap is rejected")
	check(RallyStageSession._body_crosses(Vector3(0,.5,1),Vector3(0,.5,-1),Basis.IDENTITY,Basis.IDENTITY,half,center,forward,right,opening),"An overlap already present advances when moving forward")
	var route := RallyStageRoute.new()
	route.build(RallyContentCatalog.stage("sunset_ridge"))
	var session := RallyStageSession.new()
	session.setup(route)
	session.phase = RallyStageSession.Phase.ARMED
	var pose := route.pose_at(18)
	session.previous = route.position_at(16)
	session.previous_basis = pose.basis
	session.step(pose.origin,10,.1,pose.basis,Vector3(1.88,.5,4.3))
	check(session.next_gate==1 and session.phase==RallyStageSession.Phase.RUNNING,"Runtime starts timing when the front bumper enters, before the car centre")
	finish()

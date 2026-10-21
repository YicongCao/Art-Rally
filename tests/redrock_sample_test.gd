extends "res://tests/test_suite.gd"
func _run() -> void:
 var scene: Node3D=load("res://scenes/game/challenge.tscn").instantiate()
 scene.managed_flow=true
 scene.challenge=RallyContentCatalog.challenge("redrock_canyon","R200")
 scene.challenge.stage=load("res://resources/stages/redrock_sample.tres").duplicate(true)
 scene.profile=RallyProfileStore.new()
 scene.profile.path="user://redrock-sample-test-%d/profile.json"%OS.get_process_id()
 scene.free_practice=true
 var stage: RallyStageGenerator=scene.get_node("Stage")
 stage.auto_build=false
 stage.definition=scene.challenge.stage
 root.add_child(scene)
 await stage.build_incremental(func(_value: float,_message: String): pass)
 scene.start()
 scene.controls.resume()
 scene._set_autopilot_mode_name("vgamepad")
 var saw_sand:=false
 var speed:=0.0
 for i: int in range(120*100):
  await physics_frame
  saw_sand=saw_sand or scene.vehicle.wheels[0].surface.surface_id==4
  speed=maxf(speed,scene.vehicle.linear_velocity.length())
  if scene.session.phase==RallyStageSession.Phase.FINISHED: break
 check(stage.route.length>390 and stage.route.length<410,"Prototype route is 400m")
 check(scene.session.phase==RallyStageSession.Phase.FINISHED,"R200 completes canyon / dune / rough sample")
 check(scene.session.reset_count==0,"Sample completes without recovery")
 check(saw_sand and speed>10,"Sample drives actual sand contact at speed")
 print("SAMPLE DRIVE: speed_kmh=",speed*3.6," elapsed=",scene.session.elapsed)
 scene.queue_free()
 await process_frame
 finish()

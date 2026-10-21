extends SceneTree
var app: RallyGameApp
var directory:="res://docs/expansion/runtime"
func _initialize() -> void: _run.call_deferred()
func capture(name_id: String) -> void:
 for i: int in range(12):
  paused=false
  if is_instance_valid(app.race):
   app.race.controls.resume()
   app.race.pause_menu.hide()
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory+"/"+name_id+".png")
 print("CAPTURE ",name_id)
func _run() -> void:
 root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(directory)
 app=load("res://scenes/game/game.tscn").instantiate()
 app.test_mode=true
 app.profile.path="user://expansion-capture/profile.json"
 root.add_child(app)
 AudioServer.set_bus_mute(0,true)
 app.prefs.values.reduced_motion=true
 app.show_garage()
 await capture("garage-r200")
 app.garage_category="tuning"
 RallyGaragePage.refresh_panel(app)
 await capture("garage-tuning")
 for id: String in ["I20","DELTA","EVO6","WRX","P7"]:
  app.garage_change_vehicle(id)
  app.garage_category="tires"
  app.show_garage()
  app.garage_view.target_position=Vector3(3.8,2.6,-4.3)
  await capture(id+"-front")
  app.garage_view.target_position=Vector3(-3.8,2.6,4.3)
  await capture(id+"-rear")
  app.garage_view.target_position=Vector3(4.2,2.6,4.3)
  app.garage_view.display.rotation.y=PI*.65
  await capture(id+"-side")
 app.modified_mode=false
 app.practice=true
 app.show_stages()
 await capture("stages")
 app.vehicle_page=2
 app.show_vehicles()
 await capture("vehicles")
 app.show_records()
 await capture("records")
 app.chosen_vehicle="R200"
 app.chosen_stage="redrock_canyon"
 await app.start_race()
 paused=false
 app.race.controls.resume()
 app.race.set_process(false)
 app.race.set_physics_process(false)
 app.race.vehicle.freeze=true
 app.race.game_hud.hide()
 var camera:=Camera3D.new()
 app.race.add_child(camera)
 camera.current=true
 var route: RallyStageRoute=app.race.generator.route
 for shot: Array in [["canyon-reveal",900.0,Vector3(8,5,17),65.0],["arch",2740.0,Vector3(0,28,75),20.0],["mesa",3430.0,Vector3(6,30,15),-1450.0],["driver",1130.0,Vector3(0,1.7,2),60.0]]:
  var s: float=shot[1]
  var pose:=route.pose_at(s,0)
  app.race.vehicle.global_transform=pose
  app.race.vehicle.global_position.y+=.70
  camera.global_position=pose*shot[2]
  camera.look_at(route.position_at(clampf(s+float(shot[3]),0,route.length))+Vector3.UP*1)
  await capture(shot[0])
 await app.leave_race()
 app.queue_free()
 await process_frame
 quit()

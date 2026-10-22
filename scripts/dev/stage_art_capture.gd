extends SceneTree
# Fixed chase-camera stations for art review. Use identical framing on every stage:
#   godot --path . --script res://scripts/dev/stage_art_capture.gd -- --stage=redrock_canyon --out=res://logs/art/before
var app: RallyGameApp
var directory := "res://logs/art"
var stage_id := "redrock_canyon"
var vehicle_id := "R200"

func _initialize() -> void: _run.call_deferred()

func capture(name_id: String) -> void:
 for i: int in range(10):
  paused=false
  if is_instance_valid(app.race):
   app.race.controls.resume()
   app.race.pause_menu.hide()
   for overlay: Node in app.race.find_children("*","CanvasLayer",true,false): (overlay as CanvasLayer).hide()
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory+"/"+stage_id+"-"+name_id+".png")
 print("CAPTURE ",stage_id,"-",name_id)

func _run() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--stage="): stage_id=argument.trim_prefix("--stage=")
  if argument.begins_with("--out="): directory=argument.trim_prefix("--out=")
  if argument.begins_with("--car="): vehicle_id=argument.trim_prefix("--car=")
 root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(directory)
 app=load("res://scenes/game/game.tscn").instantiate()
 app.test_mode=true
 app.profile.path="user://art-capture-%d/profile.json"%OS.get_process_id()
 root.add_child(app)
 AudioServer.set_bus_mute(0,true)
 app.prefs.values.reduced_motion=true
 app.practice=true
 app.chosen_vehicle=vehicle_id
 app.chosen_stage=stage_id
 await app.start_race()
 paused=false
 app.race.controls.resume()
 app.race.set_process(false)
 app.race.set_physics_process(false)
 app.race.vehicle.freeze=true
 app.race.game_hud.hide()
 var camera:=Camera3D.new()
 camera.fov=62
 camera.far=6200
 app.race.add_child(camera)
 camera.current=true
 var route: RallyStageRoute=app.race.generator.route
 var shots: Array=[]
 # Chase framing at evenly spaced stations, plus authored composition shots.
 for i: int in range(8):
  shots.append(["chase-%d"%i,route.length*(.04+.12*i),Vector3(0,2.7,7.8),35.0])
 if stage_id=="redrock_canyon":
  shots.append_array([["canyon-reveal",900.0,Vector3(8,5,17),65.0],["arch",2740.0,Vector3(0,28,75),20.0],["mesa",3430.0,Vector3(6,30,15),-1450.0],["driver",1130.0,Vector3(0,3.5,7),60.0],["start",40.0,Vector3(-6,4,14),40.0],["finish",route.length-20,Vector3(5,3,16),15.0],["salt-pan",1150.0,Vector3(-6,6,8),30.0,Vector3(-40,0,0)],["trading-post",1295.0,Vector3(2,3.2,8),34.0,Vector3(21,4,0)],["nomad-camp",1525.0,Vector3(-2,3.2,8),35.0,Vector3(-24,3,0)],["ghost-town",1810.0,Vector3(4,3.5,8),31.0,Vector3(20,6,0)],["balanced-rocks",2015.0,Vector3(-4,3.5,8),34.0,Vector3(-26,6,0)],["saguaro-dunes",1420.0,Vector3(0,2.7,7.8),35.0]])
 for shot: Array in shots:
  var s: float=shot[1]
  var pose:=route.pose_at(s,0)
  app.race.vehicle.global_transform=pose
  app.race.vehicle.global_position.y+=.70
  camera.global_position=pose*shot[2]
  var aim:=route.position_at(clampf(s+float(shot[3]),0,route.length))+Vector3.UP*1
  if shot.size()>4: aim=route.pose_at(s+float(shot[3]),0)*shot[4]
  camera.look_at(aim)
  await capture(shot[0])
 await app.leave_race()
 app.queue_free()
 await process_frame
 quit()

extends SceneTree
const DEST := "res://docs/art-direction/reference-cars"
var viewport: SubViewport
func _initialize() -> void: _run.call_deferred()
func snap(label: String) -> void:
 for i: int in range(24): await process_frame
 await RenderingServer.frame_post_draw
 viewport.get_texture().get_image().save_jpg(DEST+"/"+label+".jpg",.94)
 print("REFERENCE CAPTURE: ",label)
func _run() -> void:
 DirAccess.make_dir_recursive_absolute(DEST)
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var display := TextureRect.new()
 display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 display.texture=viewport.get_texture()
 root.add_child(display)
 var stage := Node3D.new()
 viewport.add_child(stage)
 var world := WorldEnvironment.new()
 world.environment=Environment.new()
 world.environment.background_mode=Environment.BG_COLOR
 world.environment.background_color=Color("cbd5d5")
 world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color=Color("d7dde3")
 world.environment.ambient_light_energy=.65
 stage.add_child(world)
 var light := DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-40,-35,0)
 light.light_energy=1.4
 light.shadow_enabled=true
 stage.add_child(light)
 var floor_mesh := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size=Vector2(200,200)
 floor_mesh.mesh=plane
 floor_mesh.position.y=-.68
 var floor_mat := StandardMaterial3D.new()
 floor_mat.albedo_color=Color("cbd5d5")
 floor_mat.roughness=1
 floor_mesh.material_override=floor_mat
 stage.add_child(floor_mesh)
 var camera := Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=3.65
 stage.add_child(camera)
 for id: String in RallyContentCatalog.VEHICLES:
  var definition := RallyContentCatalog.vehicle(id)
  var body := Node3D.new()
  stage.add_child(body)
  body.add_child(RallyVehicleAppearance.build(definition))
  RallyVehiclePlate.attach(body,definition,"ART RALLY")
  for side: float in [-1,1]:
   for axle: float in [-1,1]:
    var wheel := MeshInstance3D.new()
    wheel.mesh=RallyWheelMeshes.tire(.34)
    wheel.rotation.z=PI/2
    wheel.position=Vector3(side*definition.track_width/2,-.34,axle*definition.wheelbase/2)
    body.add_child(wheel)
    for face: float in [-1,1]:
     var rim := MeshInstance3D.new()
     rim.mesh=RallyWheelMeshes.five_spoke()
     rim.position.y=face*.125
     rim.rotation.x=PI if face<0 else 0
     wheel.add_child(rim)
  var angles := {"front":Vector3(4,2.5,-6),"rear":Vector3(-4,2.2,6),"side":Vector3(7,1.1,0)}
  for angle: String in angles:
   camera.position=angles[angle]
   camera.look_at(Vector3(0,.17,0))
   await snap(id+"-"+angle)
  body.queue_free()
  await process_frame
 stage.queue_free()
 await process_frame
 var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
 app.profile.path="user://reference-cars-review/profile.json"
 viewport.add_child(app)
 AudioServer.set_bus_mute(0,true)
 app.profile.data=RallyProfileStore.fresh()
 app.profile.data.plate="ART RALLY"
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
  viewport.size=dimensions
  app.show_vehicles()
  await snap("vehicles-%d"%dimensions.x)
  app._loading_page()
  app.progress_bar.value=60
  await snap("loading-%d"%dimensions.x)
 if "--drive" in OS.get_cmdline_user_args():
  var report := {}
  for index: int in range(3):
   app.chosen_stage=RallyContentCatalog.STAGES[index]
   app.chosen_vehicle=RallyContentCatalog.VEHICLES[index]
   await app.start_race()
   var route: RallyStageRoute=app.race.generator.route
   var station: float=[430,1390,1580][index]
   var pose := route.pose_at(station)
   app.race.session.projection_hint=route.index_at(station)
   app.race.session.previous=pose.origin
   app.race.session.progress=station
   while app.race.session.gates[app.race.session.next_gate]<station:app.race.session.next_gate+=1
   app.race.session.phase=RallyStageSession.Phase.RUNNING
   app.race.vehicle.request_reset(pose)
   app.race._set_autopilot_mode_name("vgamepad")
   app.race.auto_driver.reset_navigation(route,pose.origin)
   app.race.camera_snap=true
   for i: int in range(360):
    if paused or app.race.controls.blocked:
     paused=false
     app.race.controls.resume()
    app.race.pause_menu.show_menu(false)
    await process_frame
   var advance: float=app.race.session.progress-station
   print("DRIVE ADVANCE: ",app.chosen_vehicle," ",advance)
   if advance<=15:
    push_error("Native driving check did not advance")
    quit(1)
    return
   await snap(app.chosen_vehicle+"-driving")
   var duration: float=app.race.trajectory.frames[-1][0]
   report[app.chosen_vehicle]={"stage":app.chosen_stage,"advance_m":advance,"recorded_frames":app.race.trajectory.frames.size(),"duration":duration}
   app.race.session.phase=RallyStageSession.Phase.FINISHED
   app.show_results({"elapsed":duration,"penalty":0,"total_time":duration,"splits":[],"outcome":{"eligible":false,"new_best":false}})
   assert(app.race.replay.active,"Authored model must load into replay")
   app._set_immersive(true)
   app.race.replay.seek(duration*.65)
   app.race.replay.playing=false
   await snap(app.chosen_vehicle+"-replay")
   app._set_immersive(false)
   await app.leave_race()
  FileAccess.open(DEST+"/native-driving.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 viewport.queue_free()
 await process_frame
 quit()
